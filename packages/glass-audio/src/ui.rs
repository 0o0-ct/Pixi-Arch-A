//! UI del control de volumen (glass-audio).
//!
//! Superficie única glass + pestañas segmentadas + tarjetas One UI 8+.
//!
//! Event-driven: el estado llega por canal y se renderiza en el hilo principal
//! (sin timers de sondeo). Al re-renderizar se conserva el foco del teclado
//! mediante nombres de widget, de modo que la navegación por teclado no se
//! interrumpe con cada actualización.

use std::cell::{Cell, RefCell};
use std::collections::{HashMap, HashSet};
use std::rc::Rc;
use std::time::{SystemTime, UNIX_EPOCH};

use async_channel::{Receiver, Sender};
use audio_core::{
    format_volume_label, AudioCommand, AudioState, CardInfo, ChannelInfo, DeviceType, PeakMeter,
    PlaybackStream, PortInfo, RecordStream, VolumeTarget,
};
use gtk4::gdk::EventType;
use gtk4::pango;
use gtk4::prelude::*;
use gtk4::{
    Adjustment, Align, Application, ApplicationWindow, Box as GtkBox, Button, DropDown,
    EventControllerKey, EventControllerLegacy, Label, LevelBar, Orientation, Revealer,
    RevealerTransitionType, Scale, ScrolledWindow, Stack, StackTransitionType, Widget,
};

const TABS: [&str; 5] = [
    "Salida",
    "Entrada",
    "Reproducción",
    "Grabación",
    "Configuración",
];
const TAB_ICONS: [&str; 5] = [
    "volume_up",
    "mic",
    "play_arrow",
    "fiber_manual_record",
    "settings",
];

/// Estado compartido de la UI (se lee al renderizar, se muta en interacciones).
#[derive(Default)]
struct Ctx {
    state: AudioState,
    tab: usize,
    out_filter: usize, // 0 todos · 1 hardware · 2 virtuales
    in_filter: usize,  // 0 todos · 1 hardware · 2 monitores
    pb_filter: usize,  // 0 todos · 1 apps · 2 vídeo
    /// Pestañas con "Opciones avanzadas" abierto.
    expanded: HashSet<(u8, u32)>,
    /// Pestañas con canales desenlazados (candado abierto).
    unlocked: HashSet<(u8, u32)>,
    /// Abre "Opciones avanzadas" en todas las tarjetas (flag `--expand`).
    force_expand: bool,
}

impl Ctx {
    fn is_expanded_flag(&self, tab: u8, index: u32) -> bool {
        self.force_expand || self.expanded.contains(&(tab, index))
    }
}

struct Core {
    contents: Vec<GtkBox>,
    stack: Stack,
    tab_buttons: Vec<Button>,
    ctx: RefCell<Ctx>,
    /// `true` mientras el usuario arrastra un slider con el ratón.
    interacting: Rc<Cell<bool>>,
    cmd_tx: Sender<AudioCommand>,
    peak_tx: Sender<(u32, f32)>,
    meters: RefCell<HashMap<u32, PeakMeter>>,
    vu_bars: RefCell<HashMap<u32, Vec<LevelBar>>>,
    window: ApplicationWindow,
}

pub struct AudioWindow {
    pub window: ApplicationWindow,
    core: Rc<Core>,
}

impl AudioWindow {
    pub fn new(
        app: &Application,
        cmd_tx: Sender<AudioCommand>,
        event_rx: Receiver<AudioState>,
        initial_tab: Option<&str>,
        expand: bool,
    ) -> Self {
        let (peak_tx, peak_rx) = async_channel::unbounded::<(u32, f32)>();

        let window = ApplicationWindow::builder()
            .application(app)
            .title("Sonido")
            .default_width(720)
            .default_height(640)
            .decorated(false)
            .build();

        // ── Superficie única (100% de la ventana) ────────────────────────────
        let root = GtkBox::new(Orientation::Vertical, 0);
        root.add_css_class("audio-root");
        root.set_hexpand(true);
        root.set_vexpand(true);

        // Cabecera: título grande a la izquierda + subtítulo atenuado.
        let header = GtkBox::new(Orientation::Horizontal, 10);
        header.add_css_class("audio-header");
        header.set_hexpand(true);

        let title_box = GtkBox::new(Orientation::Vertical, 0);
        title_box.set_hexpand(true);
        let title = Label::new(Some("Sonido"));
        title.add_css_class("audio-title");
        title.set_halign(Align::Start);
        title_box.append(&title);
        let subtitle = Label::new(Some("PipeWire"));
        subtitle.add_css_class("audio-subtitle");
        subtitle.set_halign(Align::Start);
        title_box.append(&subtitle);
        header.append(&title_box);

        let close_btn = Button::new();
        close_btn.add_css_class("btn-close-window");
        close_btn.set_tooltip_text(Some("Cerrar (Esc)"));
        close_btn.set_valign(Align::Center);
        close_btn.set_child(Some(&ms_icon("close", "ms-16")));
        let win_close = window.clone();
        close_btn.connect_clicked(move |_| win_close.close());
        header.append(&close_btn);
        root.append(&header);

        // ── Pestañas segmentadas (píldora) ──────────────────────────────────
        let tab_bar = GtkBox::new(Orientation::Horizontal, 0);
        tab_bar.add_css_class("tab-bar");
        tab_bar.set_hexpand(true);
        let segmented = GtkBox::new(Orientation::Horizontal, 0);
        segmented.add_css_class("segmented");
        segmented.set_hexpand(true);
        tab_bar.append(&segmented);
        root.append(&tab_bar);

        // ── Stack de contenido con cross-fade ───────────────────────────────
        let stack = Stack::new();
        stack.set_transition_type(StackTransitionType::Crossfade);
        stack.set_transition_duration(280);
        stack.set_hexpand(true);
        stack.set_vexpand(true);

        let mut contents: Vec<GtkBox> = Vec::new();
        for (i, name) in TABS.iter().enumerate() {
            let scrolled = ScrolledWindow::builder()
                .hscrollbar_policy(gtk4::PolicyType::Never)
                .vscrollbar_policy(gtk4::PolicyType::Automatic)
                .has_frame(false)
                .propagate_natural_height(true)
                .build();
            scrolled.add_css_class("audio-scroll");
            scrolled.set_vexpand(true);

            let content = GtkBox::new(Orientation::Vertical, 12);
            content.add_css_class("audio-list");
            content.set_hexpand(true);
            scrolled.set_child(Some(&content));
            stack.add_titled(&scrolled, Some(&format!("tab{i}")), name);
            contents.push(content);
        }
        root.append(&stack);

        window.set_child(Some(&root));

        // Escape cierra la ventana.
        let key = EventControllerKey::new();
        let win_esc = window.clone();
        key.connect_key_pressed(move |_, kv, _, _| {
            if kv == gtk4::gdk::Key::Escape {
                win_esc.close();
                glib::Propagation::Stop
            } else {
                glib::Propagation::Proceed
            }
        });
        window.add_controller(key);

        // Botones de pestaña.
        let mut tab_buttons = Vec::new();
        for (i, name) in TABS.iter().enumerate() {
            let btn = Button::new();
            btn.add_css_class("seg-btn");
            btn.set_hexpand(true);
            btn.set_widget_name(&format!("tabbtn{i}"));
            let lbl = GtkBox::new(Orientation::Horizontal, 0);
            lbl.set_halign(Align::Center);
            lbl.append(&ms_icon(TAB_ICONS[i], "ms-15 seg-ic"));
            lbl.append(&Label::new(Some(name)));
            btn.set_child(Some(&lbl));
            segmented.append(&btn);
            tab_buttons.push(btn);
        }

        let mut ctx = Ctx::default();
        ctx.tab = usize::MAX; // fuerza el primer render
        let core = Rc::new(Core {
            contents,
            stack,
            tab_buttons,
            ctx: RefCell::new(ctx),
            interacting: Rc::new(Cell::new(false)),
            cmd_tx,
            peak_tx,
            meters: RefCell::new(HashMap::new()),
            vu_bars: RefCell::new(HashMap::new()),
            window: window.clone(),
        });

        for (i, btn) in core.tab_buttons.iter().enumerate() {
            let core_c = core.clone();
            btn.connect_clicked(move |_| Core::select_tab_index(&core_c, i));
        }

        {
            let mut c = core.ctx.borrow_mut();
            c.force_expand = expand;
        }

        // --tab acepta el nombre en español o el token en inglés.
        let start = match initial_tab.map(|t| t.to_ascii_lowercase()) {
            Some(t) => match t.as_str() {
                "output" | "salida" => 0,
                "input" | "entrada" => 1,
                "playback" | "reproduccion" | "reproducción" => 2,
                "record" | "grabacion" | "grabación" => 3,
                "config" | "configuracion" | "configuración" => 4,
                _ => 0,
            },
            None => 0,
        };
        Core::select_tab_index(&core, start.min(TABS.len() - 1));

        // ── Actualizaciones event-driven (coalescidas, sin sondeo) ──────────
        let core_state = core.clone();
        glib::spawn_future_local(async move {
            loop {
                let state = match event_rx.recv().await {
                    Ok(s) => s,
                    Err(_) => break,
                };
                tracing::debug!(
                    "estado recibido: {} playback (tab {})",
                    state.playback_streams.len(),
                    core_state.ctx.borrow().tab
                );
                {
                    let mut c = core_state.ctx.borrow_mut();
                    c.state = state;
                    // Drenar la cola para renderizar una sola vez por ráfaga.
                    while let Ok(more) = event_rx.try_recv() {
                        c.state = more;
                    }
                }
                if !core_state.interacting.get() {
                    Core::render(&core_state);
                }
            }
        });

        let core_peak = core.clone();
        glib::spawn_future_local(async move {
            // Evitar repintados cuando el nivel no cambia (silencio): con varios
            // monitores visibles esto mantenía la CPU ocupada sin necesidad.
            let mut last: std::collections::HashMap<u32, f64> = std::collections::HashMap::new();
            while let Ok((idx, peak)) = peak_rx.recv().await {
                let value = if peak < 0.01 { 0.0 } else { peak as f64 };
                if last.get(&idx).is_some_and(|v| (*v - value).abs() < 0.005) {
                    continue;
                }
                last.insert(idx, value);
                if let Some(bars) = core_peak.vu_bars.borrow().get(&idx) {
                    for bar in bars {
                        bar.set_value(value);
                    }
                }
            }
        });

        Self { window, core }
    }

    pub fn select_tab(&self, tab: Option<&str>) {
        if let Some(t) = tab {
            if let Some(i) = TABS.iter().position(|x| x.eq_ignore_ascii_case(t)) {
                Core::select_tab_index(&self.core, i);
            }
        }
    }
}

impl Core {
    fn select_tab_index(core: &Rc<Core>, idx: usize) {
        if idx >= TABS.len() {
            return;
        }
        {
            let mut ctx = core.ctx.borrow_mut();
            if ctx.tab == idx {
                return;
            }
            ctx.tab = idx;
        }
        for (i, b) in core.tab_buttons.iter().enumerate() {
            b.remove_css_class("active");
            if i == idx {
                b.add_css_class("active");
            }
        }
        core.stack.set_visible_child_name(&format!("tab{idx}"));
        tracing::debug!("select_tab_index({idx})");
        Core::render(core);
    }

    fn render(core: &Rc<Core>) {
        // 1. Guardar el foco (para no perder la navegación por teclado).
        let focus_key = gtk4::prelude::RootExt::focus(&core.window).and_then(|w| {
            let n = w.widget_name().to_string();
            if n.is_empty() { None } else { Some(n) }
        });

        // 2. Guardar la posición de scroll.
        let scroll_before = core
            .stack
            .visible_child()
            .and_then(|w| w.downcast_ref::<ScrolledWindow>().map(|s| s.vadjustment().value()));

        let tab = core.ctx.borrow().tab;
        tracing::debug!(
            "render: ctx.tab={tab} playback={} sinks={}",
            core.ctx.borrow().state.playback_streams.len(),
            core.ctx.borrow().state.sinks.len()
        );
        if tab >= TABS.len() {
            return;
        }

        // 3. Vaciar la página actual.
        let content = &core.contents[tab];
        while let Some(child) = content.first_child() {
            content.remove(&child);
        }
        core.vu_bars.borrow_mut().clear();

        // 4. Reconstruir.
        {
            let ctx = core.ctx.borrow();
            match tab {
                0 => render_devices(core, &ctx, DeviceKind::Sink),
                1 => render_devices(core, &ctx, DeviceKind::Source),
                2 => render_playback(core, &ctx),
                3 => render_record(core, &ctx),
                4 => render_config(core, &ctx),
                _ => {}
            }
        }

        // 5. Medidores VU: solo para las fuentes visibles (pestaña Entrada).
        sync_meters(core);

        // 6. Restaurar scroll y foco.
        if let (Some(v), Some(w)) = (scroll_before, core.stack.visible_child()) {
            if let Some(s) = w.downcast_ref::<ScrolledWindow>() {
                s.vadjustment().set_value(v);
            }
        }
        if let Some(name) = focus_key {
            if let Some(w) = find_named(core.window.upcast_ref::<Widget>(), &name) {
                w.grab_focus();
            }
        }
    }

}

// ── Utilidades ───────────────────────────────────────────────────────────────

fn ms_icon(name: &str, classes: &str) -> Label {
    let l = Label::new(Some(name));
    l.add_css_class("ms");
    for c in classes.split_whitespace() {
        l.add_css_class(c);
    }
    l.set_valign(Align::Center);
    l
}

/// Círculo tonal con icono Material Symbols (una etiqueta, sin emoji).
fn icon_circle(icon: &str) -> Label {
    let l = Label::new(Some(icon));
    l.add_css_class("ms");
    l.add_css_class("icon-circle");
    l.set_xalign(0.5);
    l.set_yalign(0.5);
    l.set_valign(Align::Start);
    l.set_halign(Align::Start);
    l
}

fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

/// Throttle de envío (debounce ~40 ms). Devuelve `true` si toca enviar.
fn throttle(last: &Cell<u128>, ms: u128) -> bool {
    let t = now_ms();
    if t.saturating_sub(last.get()) >= ms {
        last.set(t);
        true
    } else {
        false
    }
}

/// Busca un widget por su nombre en el árbol (para restaurar el foco).
fn find_named(root: &Widget, name: &str) -> Option<Widget> {
    let n = root.widget_name().to_string();
    if n == name {
        return Some(root.clone());
    }
    let mut child = root.first_child();
    while let Some(c) = child {
        if let Some(f) = find_named(&c, name) {
            return Some(f);
        }
        child = c.next_sibling();
    }
    None
}

fn toggle_set(set: &mut HashSet<(u8, u32)>, key: (u8, u32)) -> bool {
    if set.contains(&key) {
        set.remove(&key);
        false
    } else {
        set.insert(key);
        true
    }
}

fn is_hardware(desc: &str) -> bool {
    let d = desc.to_lowercase();
    !(d.contains("monitor") || d.contains("virtual") || d.contains("simul"))
}

#[derive(Clone, Copy, PartialEq)]
enum DeviceKind {
    Sink,
    Source,
}

/// Qué volumen/silencio controla un botón de la píldora.
#[derive(Clone, Copy)]
enum MuteSource {
    Sink(u32),
    Source(u32),
    Playback(u32),
    Record(u32),
}

impl MuteSource {
    fn target(self) -> VolumeTarget {
        match self {
            MuteSource::Sink(i) => VolumeTarget::Sink(i),
            MuteSource::Source(i) => VolumeTarget::Source(i),
            MuteSource::Playback(i) => VolumeTarget::PlaybackStream(i),
            MuteSource::Record(i) => VolumeTarget::RecordStream(i),
        }
    }

    fn current_muted(self, ctx: &Ctx) -> bool {
        match self {
            MuteSource::Sink(i) => ctx
                .state
                .sinks
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.muted)
                .unwrap_or(false),
            MuteSource::Source(i) => ctx
                .state
                .sources
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.muted)
                .unwrap_or(false),
            MuteSource::Playback(i) => ctx
                .state
                .playback_streams
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.muted)
                .unwrap_or(false),
            MuteSource::Record(i) => ctx
                .state
                .record_streams
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.muted)
                .unwrap_or(false),
        }
    }

    fn current_volume(self, ctx: &Ctx) -> f32 {
        match self {
            MuteSource::Sink(i) => ctx
                .state
                .sinks
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.volume)
                .unwrap_or(0.0),
            MuteSource::Source(i) => ctx
                .state
                .sources
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.volume)
                .unwrap_or(0.0),
            MuteSource::Playback(i) => ctx
                .state
                .playback_streams
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.volume)
                .unwrap_or(0.0),
            MuteSource::Record(i) => ctx
                .state
                .record_streams
                .iter()
                .find(|s| s.index == i)
                .map(|s| s.volume)
                .unwrap_or(0.0),
        }
    }
}

// ── Pestañas de dispositivos (Salida / Entrada) ──────────────────────────────

fn render_devices(core: &Rc<Core>, ctx: &Ctx, kind: DeviceKind) {
    let content = &core.contents[ctx.tab];
    let tab_id = ctx.tab as u8;

    let (title, filter_state) = match kind {
        DeviceKind::Sink => ("DISPOSITIVOS DE SALIDA", ctx.out_filter),
        DeviceKind::Source => ("DISPOSITIVOS DE ENTRADA", ctx.in_filter),
    };
    let section = Label::new(Some(title));
    section.add_css_class("audio-section");
    section.set_halign(Align::Start);
    content.append(&section);

    match kind {
        DeviceKind::Sink => {
            for s in &ctx.state.sinks {
                let hw = is_hardware(&s.description);
                match filter_state {
                    1 if !hw => continue,
                    2 if hw => continue,
                    _ => {}
                }
                let card = build_device_card(
                    core,
                    ctx,
                    tab_id,
                    DeviceKind::Sink,
                    s.index,
                    &s.description,
                    s.volume,
                    s.muted,
                    s.is_default,
                    &s.ports,
                    s.active_port.as_deref(),
                    &s.channels,
                );
                if let Some(monitor) = s.monitor_source {
                    attach_vu(core, monitor, &card);
                }
                content.append(&card);
            }
        }
        DeviceKind::Source => {
            for s in &ctx.state.sources {
                let hw = is_hardware(&s.description) && !s.is_monitor;
                match filter_state {
                    1 if !hw => continue,
                    2 if !s.is_monitor => continue,
                    _ => {}
                }
                let card = build_device_card(
                    core,
                    ctx,
                    tab_id,
                    DeviceKind::Source,
                    s.index,
                    &s.description,
                    s.volume,
                    s.muted,
                    s.is_default,
                    &s.ports,
                    s.active_port.as_deref(),
                    &s.channels,
                );
                attach_vu(core, s.index, &card);
                content.append(&card);
            }
        }
    }

    let labels: &[&str] = match kind {
        DeviceKind::Sink => &["Todos", "Hardware", "Virtuales"],
        DeviceKind::Source => &["Todos", "Hardware", "Monitores"],
    };
    content.append(&build_filter_row(core, ctx.tab, filter_state, labels));
}

fn build_filter_row(core: &Rc<Core>, tab: usize, active: usize, labels: &[&str]) -> GtkBox {
    let row = GtkBox::new(Orientation::Horizontal, 8);
    row.add_css_class("filter-row");
    let lbl = Label::new(Some("Mostrar"));
    lbl.add_css_class("filter-label");
    row.append(&lbl);
    for (i, name) in labels.iter().enumerate() {
        let chip = Button::with_label(name);
        chip.add_css_class("filter-chip");
        chip.set_widget_name(&format!("chip:{tab}:{i}"));
        if i == active {
            chip.add_css_class("active");
        }
        let core_c = core.clone();
        let idx = i;
        chip.connect_clicked(move |_| {
            {
                let mut ctx = core_c.ctx.borrow_mut();
                match tab {
                    0 => ctx.out_filter = idx,
                    1 => ctx.in_filter = idx,
                    2 => ctx.pb_filter = idx,
                    _ => {}
                }
            }
            Core::render(&core_c);
        });
        row.append(&chip);
    }
    row
}

/// Tarjeta de dispositivo (Sección B).
#[allow(clippy::too_many_arguments)]
fn build_device_card(
    core: &Rc<Core>,
    ctx: &Ctx,
    tab_id: u8,
    kind: DeviceKind,
    index: u32,
    name: &str,
    volume: f32,
    muted: bool,
    is_default: bool,
    ports: &[PortInfo],
    active_port: Option<&str>,
    chans: &[ChannelInfo],
) -> GtkBox {
    let key = format!("{tab_id}:{index}");
    let src = match kind {
        DeviceKind::Sink => MuteSource::Sink(index),
        DeviceKind::Source => MuteSource::Source(index),
    };
    let dev_type = match kind {
        DeviceKind::Sink => DeviceType::Sink,
        DeviceKind::Source => DeviceType::Source,
    };

    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("audio-card");
    card.set_hexpand(true);

    // ── Fila superior: icono tonal + nombre + puerto + check ────────────────
    let head = GtkBox::new(Orientation::Horizontal, 12);
    head.add_css_class("card-head");
    head.set_hexpand(true);

    head.append(&icon_circle(device_icon(kind, name)));

    let name_box = GtkBox::new(Orientation::Vertical, 2);
    name_box.set_hexpand(true);
    let name_lbl = Label::new(Some(name));
    name_lbl.add_css_class("card-name");
    name_lbl.set_xalign(0.0);
    name_lbl.set_hexpand(true);
    name_lbl.set_ellipsize(pango::EllipsizeMode::End);
    name_box.append(&name_lbl);

    if !ports.is_empty() {
        let port_row = GtkBox::new(Orientation::Horizontal, 6);
        port_row.add_css_class("port-row");

        let items: Vec<String> = ports
            .iter()
            .map(|p| {
                if p.available {
                    p.description.clone()
                } else {
                    format!("{} (desconectado)", p.description)
                }
            })
            .collect();
        let sel = active_port
            .and_then(|ap| ports.iter().position(|p| p.name == ap))
            .unwrap_or(0) as u32;
        let names: Vec<String> = ports.iter().map(|p| p.name.clone()).collect();
        let dd = build_dropdown(&items, sel);
        dd.set_tooltip_text(Some("Puerto"));
        dd.set_widget_name(&format!("dd:{key}"));
        dd.set_hexpand(true);
        let core_c = core.clone();
        connect_dropdown(&dd, names, move |port_name| {
            let _ = core_c.cmd_tx.send_blocking(AudioCommand::SetPort {
                device_type: dev_type,
                device_index: index,
                port_name,
            });
        });
        port_row.append(&dd);
        name_box.append(&port_row);
    }
    head.append(&name_box);

    // Check de dispositivo predeterminado.
    let check = Button::new();
    check.add_css_class("btn-tonal");
    check.set_widget_name(&format!("check:{key}"));
    if is_default {
        check.add_css_class("on");
        check.set_tooltip_text(Some("Dispositivo predeterminado"));
    } else {
        check.set_tooltip_text(Some("Establecer como predeterminado"));
    }
    let check_ic = ms_icon(
        if is_default {
            "check_circle"
        } else {
            "radio_button_unchecked"
        },
        "ms-17",
    );
    check.set_child(Some(&check_ic));
    let core_c = core.clone();
    check.connect_clicked(move |_| {
        let full_name = {
            let ctx = core_c.ctx.borrow();
            match kind {
                DeviceKind::Sink => ctx
                    .state
                    .sinks
                    .iter()
                    .find(|s| s.index == index)
                    .map(|s| s.name.clone()),
                DeviceKind::Source => ctx
                    .state
                    .sources
                    .iter()
                    .find(|s| s.index == index)
                    .map(|s| s.name.clone()),
            }
        };
        if let Some(n) = full_name {
            let _ = core_c.cmd_tx.send_blocking(AudioCommand::SetDefault {
                device_type: dev_type,
                name: n,
            });
        }
    });
    head.append(&check);
    card.append(&head);

    // ── Píldora de volumen + candado de canales ─────────────────────────────
    let pill_row = GtkBox::new(Orientation::Horizontal, 8);
    pill_row.set_hexpand(true);
    pill_row.append(&build_volume_pill(core, &key, src, volume, muted, chans.len()));

    // Candado de canales (🔗): enlaza/desenlaza los canales.
    let unlocked_now = ctx.unlocked.contains(&(tab_id, index));
    let lock_btn = Button::new();
    lock_btn.add_css_class("btn-tonal");
    lock_btn.set_widget_name(&format!("lock:{key}"));
    lock_btn.set_tooltip_text(Some(if unlocked_now {
        "Canales desenlazados"
    } else {
        "Canales enlazados"
    }));
    let lock_ic = ms_icon(if unlocked_now { "lock_open" } else { "lock" }, "ms-17");
    lock_btn.set_child(Some(&lock_ic));
    if unlocked_now {
        lock_btn.add_css_class("on");
    }
    let core_l = core.clone();
    let lock_btn_c = lock_btn.clone();
    let lock_ic_c = lock_ic.clone();
    let lock_key = (tab_id, index);
    lock_btn.connect_clicked(move |_| {
        let now = {
            let mut c = core_l.ctx.borrow_mut();
            toggle_set(&mut c.unlocked, lock_key)
        };
        lock_btn_c.set_tooltip_text(Some(if now {
            "Canales desenlazados"
        } else {
            "Canales enlazados"
        }));
        lock_ic_c.set_text(if now { "lock_open" } else { "lock" });
        if now {
            lock_btn_c.add_css_class("on");
        } else {
            lock_btn_c.remove_css_class("on");
        }
    });
    pill_row.append(&lock_btn);
    card.append(&pill_row);

    // ── Opciones avanzadas (expansor animado, sin re-render) ────────────────
    card.append(&build_advanced(
        core,
        tab_id,
        index,
        src,
        chans,
        ctx.is_expanded_flag(tab_id, index),
        unlocked_now,
    ));

    card
}

/// Píldora de volumen: botón de silencio + slider grueso + etiqueta de valor.
fn build_volume_pill(
    core: &Rc<Core>,
    key: &str,
    src: MuteSource,
    volume: f32,
    muted: bool,
    channels: usize,
) -> GtkBox {
    let target = src.target();

    let pill = GtkBox::new(Orientation::Horizontal, 6);
    pill.add_css_class("vol-pill");
    pill.set_hexpand(true);
    if muted {
        pill.add_css_class("muted");
    }
    if volume > 1.0 {
        pill.add_css_class("over");
    }

    // Botón de silencio dentro de la píldora.
    let mute_btn = Button::new();
    mute_btn.add_css_class("vol-mute");
    mute_btn.set_tooltip_text(Some("Silenciar"));
    mute_btn.set_widget_name(&format!("mute:{key}"));
    mute_btn.set_child(Some(&ms_icon(mute_icon(muted, volume), "ms-20")));
    let core_m = core.clone();
    mute_btn.connect_clicked(move |_| {
        let cur = {
            let ctx = core_m.ctx.borrow();
            src.current_muted(&ctx)
        };
        let _ = core_m.cmd_tx.send_blocking(AudioCommand::SetMute {
            target,
            muted: !cur,
        });
    });
    pill.append(&mute_btn);

    // Slider grueso.
    let pct = (volume * 100.0).clamp(0.0, 150.0);
    let upper = if volume * 100.0 > 150.0 {
        volume * 100.0
    } else {
        150.0
    };
    let adj = Adjustment::new(pct as f64, 0.0, upper as f64, 1.0, 5.0, 0.0);
    let scale = Scale::new(Orientation::Horizontal, Some(&adj));
    scale.add_css_class("vol-scale");
    scale.set_hexpand(true);
    scale.set_draw_value(false);
    scale.set_widget_name(&format!("scale:{key}"));
    if volume > 1.0 {
        scale.add_css_class("over");
    }

    // Etiqueta de valor dentro de la píldora.
    let value_lbl = Label::new(Some(&format_volume_label(volume)));
    value_lbl.add_css_class("vol-value");
    value_lbl.set_valign(Align::Center);
    value_lbl.set_xalign(1.0);

    // Arrastre con ratón: no re-renderizar mientras se arrastra.
    let inter = core.interacting.clone();
    let press = EventControllerLegacy::new();
    press.connect_event(move |_, ev| {
        if ev.event_type() == EventType::ButtonPress {
            if let Some(b) = ev.downcast_ref::<gtk4::gdk::ButtonEvent>() {
                if b.button() == 1 {
                    inter.set(true);
                }
            }
        }
        glib::Propagation::Proceed
    });
    scale.add_controller(press);

    let release = EventControllerLegacy::new();
    let inter_r = core.interacting.clone();
    let core_r = core.clone();
    let scale_r = scale.clone();
    release.connect_event(move |_, ev| {
        if ev.event_type() == EventType::ButtonRelease {
            if let Some(b) = ev.downcast_ref::<gtk4::gdk::ButtonEvent>() {
                if b.button() == 1 {
                    inter_r.set(false);
                    // Enviar el valor final (el throttle pudo retenerlo).
                    let p = (scale_r.value() as f32) / 100.0;
                    let cur = {
                        let ctx = core_r.ctx.borrow();
                        src.current_volume(&ctx)
                    };
                    if (p - cur).abs() > 0.001 {
                        let _ = core_r.cmd_tx.send_blocking(AudioCommand::SetVolume {
                            target,
                            volume: p,
                            channels,
                        });
                    }
                    // Refrescar cuando el eco del estado llegue (o por si acaso).
                    let core_f = core_r.clone();
                    glib::timeout_add_local_once(
                        std::time::Duration::from_millis(160),
                        move || Core::render(&core_f),
                    );
                }
            }
        }
        glib::Propagation::Proceed
    });
    scale.add_controller(release);

    // Envío con throttle ~40 ms.
    let last_sent = Rc::new(Cell::new(0u128));
    let pill_c = pill.clone();
    let lbl_c = value_lbl.clone();
    let scale_c = scale.clone();
    let core_v = core.clone();
    scale.connect_value_changed(move |s| {
        let p = (s.value() as f32) / 100.0;
        lbl_c.set_text(&format_volume_label(p));
        update_pill_classes(&pill_c, &scale_c, p);
        if throttle(&last_sent, 40) {
            let _ = core_v.cmd_tx.send_blocking(AudioCommand::SetVolume {
                target,
                volume: p,
                channels,
            });
        }
    });

    pill.append(&scale);
    pill.append(&value_lbl);
    pill
}

/// Sección "Opciones avanzadas" (balance + canales individuales + formato).
fn build_advanced(
    core: &Rc<Core>,
    tab_id: u8,
    index: u32,
    src: MuteSource,
    chans: &[ChannelInfo],
    expanded: bool,
    unlocked: bool,
) -> GtkBox {
    let key = format!("{tab_id}:{index}");
    let target = src.target();

    let wrap = GtkBox::new(Orientation::Vertical, 0);

    let adv_btn = Button::new();
    adv_btn.add_css_class("adv-btn");
    adv_btn.set_widget_name(&format!("adv:{key}"));
    adv_btn.set_halign(Align::Start);
    if expanded {
        adv_btn.add_css_class("open");
    }
    let btn_row = GtkBox::new(Orientation::Horizontal, 0);
    let chev = ms_icon("expand_more", "ms-18 chev");
    btn_row.append(&chev);
    btn_row.append(&Label::new(Some("Opciones avanzadas")));
    adv_btn.set_child(Some(&btn_row));

    // Contenido (siempre construido; se muestra con cross-fade).
    let adv_box = GtkBox::new(Orientation::Vertical, 10);
    adv_box.add_css_class("adv-box");

    // Balance (solo estéreo).
    if chans.len() == 2 {
        let row = GtkBox::new(Orientation::Horizontal, 10);
        row.add_css_class("adv-row");
        let k = Label::new(Some("Balance"));
        k.add_css_class("adv-key");
        row.append(&k);
        let badj = Adjustment::new(stereo_balance(chans) as f64, -1.0, 1.0, 0.05, 0.2, 0.0);
        let bscale = Scale::new(Orientation::Horizontal, Some(&badj));
        bscale.add_css_class("mini-scale");
        bscale.set_hexpand(true);
        bscale.set_draw_value(false);
        bscale.set_widget_name(&format!("bal:{key}"));
        let last_b = Rc::new(Cell::new(0u128));
        let core_b = core.clone();
        bscale.connect_value_changed(move |s| {
            if throttle(&last_b, 40) {
                let _ = core_b.cmd_tx.send_blocking(AudioCommand::SetBalance {
                    target,
                    balance: s.value() as f32,
                });
            }
        });
        row.append(&bscale);
        adv_box.append(&row);
    }

    // Sliders individuales (solo con candado abierto).
    let ch_box = GtkBox::new(Orientation::Vertical, 6);
    ch_box.set_visible(unlocked);
    for (i, ch) in chans.iter().enumerate() {
        let row = GtkBox::new(Orientation::Horizontal, 10);
        row.add_css_class("adv-row");
        let k = Label::new(Some(&channel_label(&ch.name, i)));
        k.add_css_class("adv-key");
        row.append(&k);
        let cval = (ch.volume * 100.0).clamp(0.0, 150.0) as f64;
        let cadj = Adjustment::new(cval, 0.0, 150.0, 1.0, 5.0, 0.0);
        let cscale = Scale::new(Orientation::Horizontal, Some(&cadj));
        cscale.add_css_class("mini-scale");
        cscale.set_hexpand(true);
        cscale.set_draw_value(false);
        cscale.set_widget_name(&format!("ch:{key}:{i}"));
        let last_c = Rc::new(Cell::new(0u128));
        let core_c = core.clone();
        let ch_i = i;
        cscale.connect_value_changed(move |s| {
            if throttle(&last_c, 40) {
                let vals = channel_values(core_c.as_ref(), src, ch_i, s.value() as f32 / 100.0);
                let _ = core_c.cmd_tx.send_blocking(AudioCommand::SetChannelVolumes {
                    target,
                    channels: vals,
                });
            }
        });
        row.append(&cscale);
        ch_box.append(&row);
    }
    adv_box.append(&ch_box);

    let info = Label::new(Some(&format!(
        "{} canales · control en tiempo real",
        chans.len()
    )));
    info.add_css_class("card-meta");
    info.set_halign(Align::Start);
    adv_box.append(&info);

    // Revelador animado: SlideDown (250 ms) anima la altura de verdad y no
    // reserva espacio cuando está cerrado; el fundido lo aporta la clase CSS.
    adv_box.add_css_class("adv-body");
    if expanded {
        adv_box.add_css_class("shown");
    }
    let revealer = Revealer::new();
    revealer.set_transition_type(RevealerTransitionType::SlideDown);
    revealer.set_transition_duration(250);
    revealer.set_child(Some(&adv_box));
    revealer.set_reveal_child(expanded);

    // Alternar sin re-render (mantiene animación y foco).
    let core_a = core.clone();
    let adv_btn_c = adv_btn.clone();
    let adv_box_c = adv_box.clone();
    let revealer_c = revealer.clone();
    let adv_key = (tab_id, index);
    adv_btn.connect_clicked(move |_| {
        let now = {
            let mut c = core_a.ctx.borrow_mut();
            toggle_set(&mut c.expanded, adv_key)
        };
        revealer_c.set_reveal_child(now);
        if now {
            adv_box_c.add_css_class("shown");
            adv_btn_c.add_css_class("open");
        } else {
            adv_box_c.remove_css_class("shown");
            adv_btn_c.remove_css_class("open");
        }
    });

    wrap.append(&adv_btn);
    wrap.append(&revealer);
    wrap
}

/// Balance estéreo aproximado (−1 izquierda … +1 derecha).
fn stereo_balance(chans: &[ChannelInfo]) -> f32 {
    if chans.len() != 2 {
        return 0.0;
    }
    let sum = chans[0].volume + chans[1].volume;
    if sum <= 0.0001 {
        0.0
    } else {
        ((chans[1].volume - chans[0].volume) / sum).clamp(-1.0, 1.0)
    }
}

fn channel_label(name: &str, i: usize) -> String {
    let n = name.to_lowercase();
    if n.contains("left") || n.contains("izquier") {
        "Izquierdo".into()
    } else if n.contains("right") || n.contains("derech") {
        "Derecho".into()
    } else if n.contains("front") {
        format!("Frontal {}", i + 1)
    } else {
        format!("Canal {}", i + 1)
    }
}

/// Valores de canal actuales con el canal `changed` actualizado.
fn channel_values(core: &Core, src: MuteSource, changed: usize, value: f32) -> Vec<f32> {
    let ctx = core.ctx.borrow();
    let chans: Vec<ChannelInfo> = match src {
        MuteSource::Sink(i) => ctx
            .state
            .sinks
            .iter()
            .find(|s| s.index == i)
            .map(|s| s.channels.clone())
            .unwrap_or_default(),
        MuteSource::Source(i) => ctx
            .state
            .sources
            .iter()
            .find(|s| s.index == i)
            .map(|s| s.channels.clone())
            .unwrap_or_default(),
        MuteSource::Playback(i) => ctx
            .state
            .playback_streams
            .iter()
            .find(|s| s.index == i)
            .map(|s| s.channels.clone())
            .unwrap_or_default(),
        MuteSource::Record(i) => ctx
            .state
            .record_streams
            .iter()
            .find(|s| s.index == i)
            .map(|s| s.channels.clone())
            .unwrap_or_default(),
    };
    let mut vals: Vec<f32> = if chans.is_empty() {
        vec![value]
    } else {
        chans.iter().map(|c| c.volume).collect()
    };
    if changed < vals.len() {
        vals[changed] = value;
    }
    vals
}

fn attach_vu(core: &Rc<Core>, source_index: u32, card: &GtkBox) {
    let row = GtkBox::new(Orientation::Horizontal, 0);
    let bar = LevelBar::for_interval(0.0, 1.0);
    bar.add_css_class("vu-thin");
    bar.set_hexpand(true);
    row.append(&bar);
    card.append(&row);

    core.vu_bars
        .borrow_mut()
        .entry(source_index)
        .or_default()
        .push(bar);

    // Asegurar un medidor para este source (uno por fuente visible).
    let needs = !core.meters.borrow().contains_key(&source_index);
    if needs {
        let name = {
            let ctx = core.ctx.borrow();
            ctx.state
                .sources
                .iter()
                .find(|s| s.index == source_index)
                .map(|s| s.name.clone())
        };
        if let Some(name) = name {
            let meter = PeakMeter::spawn(source_index, name, core.peak_tx.clone());
            core.meters.borrow_mut().insert(source_index, meter);
        }
    }
}

/// Detiene los medidores de fuentes que ya no están visibles.
fn sync_meters(core: &Rc<Core>) {
    let ctx = core.ctx.borrow();
    let visible: HashSet<u32> = match ctx.tab {
        // Salida: monitor de cada sink visible.
        0 => ctx
            .state
            .sinks
            .iter()
            .filter_map(|s| s.monitor_source)
            .collect(),
        // Entrada: cada fuente.
        1 => ctx.state.sources.iter().map(|s| s.index).collect(),
        // Reproducción: monitor del sink de cada stream.
        2 => ctx
            .state
            .playback_streams
            .iter()
            .filter_map(|p| {
                ctx.state
                    .sinks
                    .iter()
                    .find(|k| k.index == p.sink_index)
                    .and_then(|k| k.monitor_source)
            })
            .collect(),
        // Grabación: la fuente que graba cada stream.
        3 => ctx.state.record_streams.iter().map(|r| r.source_index).collect(),
        _ => HashSet::new(),
    };
    drop(ctx);
    let mut meters = core.meters.borrow_mut();
    let stale: Vec<u32> = meters
        .keys()
        .copied()
        .filter(|i| !visible.contains(i))
        .collect();
    for i in stale {
        meters.remove(&i); // Drop → envía la orden de parada
    }
}

// ── Pestaña Reproducción ─────────────────────────────────────────────────────

fn render_playback(core: &Rc<Core>, ctx: &Ctx) {
    let content = &core.contents[ctx.tab];
    let section = Label::new(Some("APLICACIONES QUE REPRODUCEN AUDIO"));
    section.add_css_class("audio-section");
    section.set_halign(Align::Start);
    content.append(&section);

    let filter = ctx.pb_filter;
    let devices: Vec<(u32, String)> = ctx
        .state
        .sinks
        .iter()
        .map(|k| (k.index, k.description.clone()))
        .collect();

    let streams: Vec<&PlaybackStream> = ctx
        .state
        .playback_streams
        .iter()
        .filter(|s| match filter {
            1 => !is_video(&s.media_role, &s.app_name),
            2 => is_video(&s.media_role, &s.app_name),
            _ => true,
        })
        .collect();

    if streams.is_empty() {
        let empty = Label::new(Some("No hay aplicaciones reproduciendo audio"));
        empty.add_css_class("empty-state");
        empty.set_xalign(0.5);
        content.append(&empty);
    }

    for s in streams {
        let card = build_stream_card(
            core,
            2,
            s.index,
            &s.app_name,
            &s.media_name,
            s.volume,
            s.muted,
            s.sink_index,
            &s.channels,
            MuteSource::Playback(s.index),
            DeviceKind::Sink,
            &devices,
        );
        if let Some(monitor) = ctx
            .state
            .sinks
            .iter()
            .find(|k| k.index == s.sink_index)
            .and_then(|k| k.monitor_source)
        {
            attach_vu(core, monitor, &card);
        }
        content.append(&card);
    }

    content.append(&build_filter_row(
        core,
        ctx.tab,
        filter,
        &["Todos", "Aplicaciones", "Vídeo"],
    ));
}

// ── Pestaña Grabación ────────────────────────────────────────────────────────

fn render_record(core: &Rc<Core>, ctx: &Ctx) {
    let content = &core.contents[ctx.tab];
    let section = Label::new(Some("APLICACIONES QUE GRABAN AUDIO"));
    section.add_css_class("audio-section");
    section.set_halign(Align::Start);
    content.append(&section);

    let devices: Vec<(u32, String)> = ctx
        .state
        .sources
        .iter()
        .filter(|k| !k.is_monitor)
        .map(|k| (k.index, k.description.clone()))
        .collect();

    let streams: Vec<&RecordStream> = ctx.state.record_streams.iter().collect();
    if streams.is_empty() {
        let empty = Label::new(Some("No hay aplicaciones grabando audio"));
        empty.add_css_class("empty-state");
        empty.set_xalign(0.5);
        content.append(&empty);
    }

    for s in streams {
        let card = build_stream_card(
            core,
            3,
            s.index,
            &s.app_name,
            &s.media_name,
            s.volume,
            s.muted,
            s.source_index,
            &s.channels,
            MuteSource::Record(s.index),
            DeviceKind::Source,
            &devices,
        );
        attach_vu(core, s.source_index, &card);
        content.append(&card);
    }
}

/// Tarjeta de stream (Reproducción / Grabación) con selector de dispositivo.
#[allow(clippy::too_many_arguments)]
fn build_stream_card(
    core: &Rc<Core>,
    tab_id: u8,
    index: u32,
    app_name: &str,
    media_name: &str,
    volume: f32,
    muted: bool,
    current_device: u32,
    chans: &[ChannelInfo],
    src: MuteSource,
    kind: DeviceKind,
    devices: &[(u32, String)],
) -> GtkBox {
    let key = format!("{tab_id}:{index}");

    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("audio-card");
    card.set_hexpand(true);

    // Cabecera.
    let head = GtkBox::new(Orientation::Horizontal, 12);
    head.add_css_class("card-head");
    head.set_hexpand(true);

    let icon = match kind {
        DeviceKind::Sink => {
            if is_video("", app_name) {
                "movie"
            } else {
                "play_arrow"
            }
        }
        DeviceKind::Source => "fiber_manual_record",
    };
    head.append(&icon_circle(icon));

    let name_box = GtkBox::new(Orientation::Vertical, 2);
    name_box.set_hexpand(true);
    let name_lbl = Label::new(Some(app_name));
    name_lbl.add_css_class("card-name");
    name_lbl.set_xalign(0.0);
    name_lbl.set_hexpand(true);
    name_lbl.set_ellipsize(pango::EllipsizeMode::End);
    name_box.append(&name_lbl);
    if !media_name.is_empty() {
        let meta = Label::new(Some(media_name));
        meta.add_css_class("card-meta");
        meta.set_xalign(0.0);
        meta.set_hexpand(true);
        meta.set_ellipsize(pango::EllipsizeMode::End);
        name_box.append(&meta);
    }
    head.append(&name_box);
    card.append(&head);

    // Selector de dispositivo (mover stream).
    if !devices.is_empty() {
        let drow = GtkBox::new(Orientation::Horizontal, 8);
        drow.add_css_class("port-row");
        let dlabel = Label::new(Some(match kind {
            DeviceKind::Sink => "Dispositivo",
            DeviceKind::Source => "Entrada",
        }));
        dlabel.add_css_class("port-label");
        drow.append(&dlabel);

        let items: Vec<String> = devices.iter().map(|(_, d)| d.clone()).collect();
        let names: Vec<String> = devices.iter().map(|(i, _)| i.to_string()).collect();
        let sel = devices
            .iter()
            .position(|(i, _)| *i == current_device)
            .unwrap_or(0) as u32;
        let dd = build_dropdown(&items, sel);
        dd.set_widget_name(&format!("dd:{key}"));
        dd.set_hexpand(true);
        let core_c = core.clone();
        let dev_type = match kind {
            DeviceKind::Sink => DeviceType::Sink,
            DeviceKind::Source => DeviceType::Source,
        };
        connect_dropdown(&dd, names, move |dev_idx| {
            if let Ok(di) = dev_idx.parse::<u32>() {
                let _ = core_c.cmd_tx.send_blocking(AudioCommand::MoveStream {
                    stream_index: index,
                    device_index: di,
                    device_type: dev_type,
                });
            }
        });
        drow.append(&dd);
        card.append(&drow);
    }

    // Píldora de volumen.
    card.append(&build_volume_pill(
        core,
        &key,
        src,
        volume,
        muted,
        chans.len(),
    ));

    card
}

// ── Pestaña Configuración ────────────────────────────────────────────────────

fn render_config(core: &Rc<Core>, ctx: &Ctx) {
    let content = &core.contents[ctx.tab];
    let section = Label::new(Some("TARJETAS DE AUDIO"));
    section.add_css_class("audio-section");
    section.set_halign(Align::Start);
    content.append(&section);

    if ctx.state.cards.is_empty() {
        let empty = Label::new(Some("No se encontraron tarjetas de audio"));
        empty.add_css_class("empty-state");
        empty.set_xalign(0.5);
        content.append(&empty);
    }

    for info in &ctx.state.cards {
        content.append(&build_config_card(core, info));
    }
}

fn build_config_card(core: &Rc<Core>, info: &CardInfo) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("audio-card");
    card.set_hexpand(true);

    let head = GtkBox::new(Orientation::Horizontal, 12);
    head.add_css_class("card-head");
    head.set_hexpand(true);
    head.append(&icon_circle("settings_input_component"));

    let name_box = GtkBox::new(Orientation::Vertical, 2);
    name_box.set_hexpand(true);
    let name_lbl = Label::new(Some(&info.description));
    name_lbl.add_css_class("card-name");
    name_lbl.set_xalign(0.0);
    name_lbl.set_hexpand(true);
    name_lbl.set_ellipsize(pango::EllipsizeMode::End);
    name_box.append(&name_lbl);
    let meta = Label::new(Some(&format!("{} perfiles · {}", info.name, info.profiles.len())));
    meta.add_css_class("card-meta");
    meta.set_xalign(0.0);
    name_box.append(&meta);
    head.append(&name_box);
    card.append(&head);

    if !info.profiles.is_empty() {
        let prow = GtkBox::new(Orientation::Horizontal, 8);
        prow.add_css_class("port-row");
        let plabel = Label::new(Some("Perfil"));
        plabel.add_css_class("port-label");
        prow.append(&plabel);

        let items: Vec<String> = info
            .profiles
            .iter()
            .map(|p| {
                if p.available {
                    p.description.clone()
                } else {
                    format!("{} (no disponible)", p.description)
                }
            })
            .collect();
        let names: Vec<String> = info.profiles.iter().map(|p| p.name.clone()).collect();
        let sel = info
            .active_profile
            .as_ref()
            .and_then(|ap| info.profiles.iter().position(|p| &p.name == ap))
            .unwrap_or(0) as u32;
        let dd = build_dropdown(&items, sel);
        dd.set_widget_name(&format!("dd:4:{}", info.index));
        dd.set_hexpand(true);
        let core_c = core.clone();
        let card_index = info.index;
        connect_dropdown(&dd, names, move |profile| {
            let _ = core_c.cmd_tx.send_blocking(AudioCommand::SetCardProfile {
                card_index,
                profile_name: profile,
            });
        });
        prow.append(&dd);
        card.append(&prow);
    }

    card
}

// ── Helpers compartidos ──────────────────────────────────────────────────────

fn build_dropdown(items: &[String], selected: u32) -> DropDown {
    let strs: Vec<&str> = items.iter().map(|s| s.as_str()).collect();
    let dd = DropDown::from_strings(&strs);
    dd.set_selected((selected as usize).min(items.len().saturating_sub(1)) as u32);
    dd.add_css_class("port-select");
    dd
}

fn connect_dropdown<F: Fn(String) + 'static>(dd: &DropDown, names: Vec<String>, on_select: F) {
    dd.connect_selected_notify(move |d| {
        let idx = d.selected() as usize;
        if let Some(n) = names.get(idx) {
            on_select(n.clone());
        }
    });
}

fn update_pill_classes(pill: &GtkBox, scale: &Scale, pct: f32) {
    if pct > 1.0 {
        pill.add_css_class("over");
        scale.add_css_class("over");
    } else {
        pill.remove_css_class("over");
        scale.remove_css_class("over");
    }
    if pct <= 0.0 {
        pill.add_css_class("muted");
    } else {
        pill.remove_css_class("muted");
    }
}

fn mute_icon(muted: bool, volume: f32) -> &'static str {
    if muted || volume <= 0.0 {
        "volume_off"
    } else if volume < 0.5 {
        "volume_down"
    } else {
        "volume_up"
    }
}

fn device_icon(kind: DeviceKind, name: &str) -> &'static str {
    let n = name.to_lowercase();
    match kind {
        DeviceKind::Sink => {
            if n.contains("hdmi") || n.contains("displayport") {
                "settings_input_component"
            } else if n.contains("speaker") || n.contains("altavoz") {
                "speaker"
            } else if n.contains("headphone") || n.contains("auricular") {
                "headphones"
            } else {
                "volume_up"
            }
        }
        DeviceKind::Source => {
            if n.contains("monitor") {
                "speaker"
            } else {
                "mic"
            }
        }
    }
}

fn is_video(media_role: &str, app_name: &str) -> bool {
    let r = media_role.to_lowercase();
    let a = app_name.to_lowercase();
    r == "video"
        || a.contains("mpv")
        || a.contains("vlc")
        || a.contains("firefox")
        || a.contains("chrome")
        || a.contains("video")
}
