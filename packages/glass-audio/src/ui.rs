//! Interfaz del mezclador One UI 8.5: barras de relleno, pestañas compactas,
//! filtros, dispositivos, perfiles e interruptores. Solo presentación: la
//! lógica de audio vive en audio-core y no se modifica aquí.

use crate::MixerState;
use audio_core::{AudioCommand, AudioState, CardInfo, DeviceType, ProfileInfo, VolumeTarget};
use gtk4::prelude::*;
use gtk4::{
    Align, Adjustment, Box as GtkBox, Button, DropDown, Image, Label, Orientation, Overlay, Scale,
    ScrolledWindow, Stack, StackTransitionType, StringList, Switch,
};
use std::{
    cell::{Cell, RefCell},
    collections::HashMap,
    rc::Rc,
    time::{Duration, Instant},
};

// ── Pestañas ──────────────────────────────────────────────────────────────

#[derive(Clone, Copy, PartialEq, Eq, Default)]
enum Tab {
    #[default]
    Playback,
    Record,
    Output,
    Input,
    Config,
}

impl Tab {
    const ALL: [Tab; 5] = [Self::Playback, Self::Record, Self::Output, Self::Input, Self::Config];

    fn name(self) -> &'static str {
        match self {
            Self::Playback => "playback",
            Self::Record => "record",
            Self::Output => "output",
            Self::Input => "input",
            Self::Config => "config",
        }
    }
    fn label(self) -> &'static str {
        match self {
            Self::Playback => "Reproducción",
            Self::Record => "Grabación",
            Self::Output => "Dispositivos de salida",
            Self::Input => "Dispositivos de entrada",
            Self::Config => "Configuración",
        }
    }
    fn icon(self) -> &'static str {
        match self {
            Self::Playback => "media-playback-start-symbolic",
            Self::Record => "media-record-symbolic",
            Self::Output => "audio-speakers-symbolic",
            Self::Input => "audio-input-microphone-symbolic",
            Self::Config => "preferences-system-symbolic",
        }
    }
    /// Opciones del selector "Mostrar:". Configuración usa interruptores.
    fn filters(self) -> &'static [&'static str] {
        match self {
            Self::Playback | Self::Record => &["Aplicaciones", "Todos los streams"],
            Self::Output => &["Todos los dispositivos de salida", "Disponibles"],
            Self::Input => &["Todos excepto los monitores", "Todos los dispositivos de entrada"],
            Self::Config => &[],
        }
    }
    fn from_name(name: &str) -> Self {
        match name {
            "record" => Self::Record,
            "output" => Self::Output,
            "input" => Self::Input,
            "config" => Self::Config,
            _ => Self::Playback,
        }
    }
}

// ── Utilidades ────────────────────────────────────────────────────────────

fn label(text: &str, class: &str) -> Label {
    let widget = Label::new(Some(text));
    widget.add_css_class(class);
    widget
}

fn icon(name: &str, class: &str) -> Image {
    let widget = Image::from_icon_name(name);
    widget.add_css_class(class);
    widget
}

fn icon_button(name: &str, class: &str, tooltip: &str) -> Button {
    let widget = Button::new();
    widget.set_child(Some(&icon(name, "button-icon")));
    widget.add_css_class(class);
    widget.set_tooltip_text(Some(tooltip));
    widget
}

/// Icono del dispositivo según su descripción.
fn device_icon(description: &str, source: bool) -> Image {
    let text = description.to_lowercase();
    let name = if source || text.contains("microphone") || text.contains("mic ") {
        "audio-input-microphone-symbolic"
    } else if text.contains("hdmi") || text.contains("displayport") || text.contains("monitor") {
        "video-display-symbolic"
    } else if text.contains("headset") {
        "audio-headset-symbolic"
    } else if text.contains("headphone") {
        "audio-headphones-symbolic"
    } else {
        "audio-speakers-symbolic"
    };
    icon(name, "device-icon")
}

fn send(state: &MixerState, command: AudioCommand) {
    state.send(command);
}

fn target_key(target: VolumeTarget) -> String {
    format!("{target:?}")
}

fn percent_text(volume: f32) -> String {
    format!("{}%", (volume.max(0.0) * 100.0).round() as i32)
}

fn db_text(volume: f32) -> String {
    if volume <= 0.000_001 {
        "−∞ dB".into()
    } else {
        format!("{:.2} dB", 60.0 * volume.log10())
    }
}

/// Mantiene el volumen por canales (o todos a la vez) sin tocar audio-core.
fn channels_for(state: &MixerState, target: VolumeTarget, current: &[f32], volume: f32) {
    if !state.unlocked.borrow().contains(&target_key(target)) || current.is_empty() {
        send(
            state,
            AudioCommand::SetVolume {
                target,
                volume,
                channels: current.len().max(1),
            },
        );
        return;
    }
    let average = current.iter().copied().sum::<f32>() / current.len() as f32;
    let values = if average <= f32::EPSILON {
        vec![volume; current.len()]
    } else {
        current
            .iter()
            .map(|channel| (channel * volume / average).clamp(0.0, 1.5))
            .collect()
    };
    send(
        state,
        AudioCommand::SetChannelVolumes {
            target,
            channels: values,
        },
    );
}

fn channels(volume: &[audio_core::ChannelInfo]) -> Vec<f32> {
    volume.iter().map(|channel| channel.volume).collect()
}

fn set_default(state: &MixerState, device_type: DeviceType, name: String) {
    send(state, AudioCommand::SetDefault { device_type, name });
}

/// Volumen y mute de un objetivo a partir del estado recibido.
fn lookup_audio(audio: &AudioState, target: VolumeTarget) -> Option<(f32, bool)> {
    match target {
        VolumeTarget::Sink(index) => audio
            .sinks
            .iter()
            .find(|device| device.index == index)
            .map(|device| (device.volume, device.muted)),
        VolumeTarget::Source(index) => audio
            .sources
            .iter()
            .find(|device| device.index == index)
            .map(|device| (device.volume, device.muted)),
        VolumeTarget::PlaybackStream(index) => audio
            .playback_streams
            .iter()
            .find(|stream| stream.index == index)
            .map(|stream| (stream.volume, stream.muted)),
        VolumeTarget::RecordStream(index) => audio
            .record_streams
            .iter()
            .find(|stream| stream.index == index)
            .map(|stream| (stream.volume, stream.muted)),
    }
}

// ── Referencias a una barra para actualizar in-place ──────────────────────

#[derive(Clone)]
struct BarRefs {
    target: VolumeTarget,
    scale: Scale,
    value_label: Option<Label>,
    mute_image: Option<Image>,
    app_icon: String,
    updating: Rc<Cell<bool>>,
}

impl BarRefs {
    /// Refresca una barra existente sin reconstruir widgets.
    fn update(&self, volume: f32, muted: bool) {
        self.updating.set(true);
        self.scale.set_value(volume.clamp(0.0, 1.5) as f64);
        self.updating.set(false);
        if volume > 1.0 {
            self.scale.add_css_class("over-100");
        } else {
            self.scale.remove_css_class("over-100");
        }
        if let Some(value) = &self.value_label {
            value.set_label(&percent_text(volume));
        }
        if let Some(image) = &self.mute_image {
            let name = if muted || volume <= 0.0 {
                "audio-volume-muted-symbolic"
            } else {
                self.app_icon.as_str()
            };
            image.set_icon_name(Some(name));
        }
    }
}

type Bars = Rc<RefCell<HashMap<String, BarRefs>>>;

// ── Referencias de la UI ──────────────────────────────────────────────────

#[derive(Clone)]
struct UiRefs {
    pages: Rc<RefCell<Vec<(Tab, ScrolledWindow)>>>,
    tabs: Rc<RefCell<Vec<(Tab, Button, Label)>>>,
    stack: Stack,
    filter_bar: GtkBox,
    filter_combo: DropDown,
    updating_filter: Rc<Cell<bool>>,
    last_tab: Rc<RefCell<String>>,
    bars: Bars,
}

/// Reconstruye la UI, salvo que haya un arrastre activo: en ese caso solo
/// actualiza los valores de las barras que el usuario no está moviendo.
fn rebuild(refs: &UiRefs, state: &MixerState) {
    let tab = Tab::from_name(&state.current_tab.borrow());

    if state.dragging.get() {
        let snapshot = state.audio.borrow().clone();
        let dragging = state.dragging_target.borrow().clone();
        for bar in refs.bars.borrow().values() {
            if dragging.as_deref() == Some(target_key(bar.target).as_str()) {
                continue;
            }
            if let Some((volume, muted)) = lookup_audio(&snapshot, bar.target) {
                bar.update(volume, muted);
            }
        }
        return;
    }

    refs.bars.borrow_mut().clear();
    let snapshot = state.audio.borrow().clone();
    for (item, page) in refs.pages.borrow().iter() {
        page.set_child(Some(&build_page(*item, state, &snapshot, &refs.bars)));
    }

    for (item, button, tab_label) in refs.tabs.borrow().iter() {
        let active = *item == tab;
        if active {
            button.add_css_class("active");
            button.remove_css_class("inactive");
        } else {
            button.remove_css_class("active");
            button.add_css_class("inactive");
        }
        tab_label.set_visible(active);
    }

    let options = tab.filters();
    refs.filter_bar.set_visible(!options.is_empty());
    if *refs.last_tab.borrow() != tab.name() {
        *refs.last_tab.borrow_mut() = tab.name().to_string();
        if !options.is_empty() {
            refs.updating_filter.set(true);
            refs.filter_combo.set_model(Some(&StringList::new(options)));
            refs.filter_combo
                .set_selected(state.filter_index(tab.name()) as u32);
            refs.updating_filter.set(false);
        }
    }

    // Recupera el foco de la barra que se estaba usando con el teclado.
    let focus = state.focus_target.borrow().clone();
    if let Some(key) = focus {
        if let Some(bar) = refs.bars.borrow().get(&key) {
            bar.scale.grab_focus();
        }
        state.focus_target.borrow_mut().take();
    }
}

// ── Construcción principal ────────────────────────────────────────────────

pub fn build_mixer(
    state: MixerState,
    window: gtk4::ApplicationWindow,
) -> (GtkBox, impl Fn() + 'static) {
    let outer = GtkBox::new(Orientation::Vertical, 0);
    outer.add_css_class("audio-shell");
    let panel = GtkBox::new(Orientation::Vertical, 0);
    panel.add_css_class("audio-panel");
    panel.set_hexpand(true);
    panel.set_vexpand(true);
    outer.append(&panel);

    // Cabecera
    let header = GtkBox::new(Orientation::Horizontal, 12);
    header.add_css_class("audio-header");
    let heading = GtkBox::new(Orientation::Vertical, 2);
    heading.set_hexpand(true);
    heading.append(&label("Sonido", "audio-title"));
    let server = state.audio.borrow().server_name.clone();
    heading.append(&label(
        if server.is_empty() { "PipeWire" } else { &server },
        "audio-subtitle",
    ));
    header.append(&heading);
    let close = icon_button("window-close-symbolic", "round-action", "Cerrar");
    let close_window = window.clone();
    close.connect_clicked(move |_| close_window.close());
    header.append(&close);
    panel.append(&header);

    let tab_bar = GtkBox::new(Orientation::Horizontal, 4);
    tab_bar.add_css_class("tab-bar");
    let stack = Stack::new();
    stack.add_css_class("audio-stack");
    stack.set_hexpand(true);
    stack.set_vexpand(true);
    stack.set_transition_type(StackTransitionType::Crossfade);
    stack.set_transition_duration(180);

    let pages: Rc<RefCell<Vec<(Tab, ScrolledWindow)>>> = Rc::new(RefCell::new(Vec::new()));
    let tabs: Rc<RefCell<Vec<(Tab, Button, Label)>>> = Rc::new(RefCell::new(Vec::new()));
    let bars: Bars = Rc::new(RefCell::new(HashMap::new()));

    // Barra inferior fija "Mostrar:"
    let filter_bar = GtkBox::new(Orientation::Horizontal, 10);
    filter_bar.add_css_class("filter-bar");
    filter_bar.append(&label("Mostrar:", "filter-label"));
    let filter_combo = DropDown::from_strings(Tab::default().filters());
    filter_combo.add_css_class("filter-combo");
    filter_bar.append(&filter_combo);

    let refs = UiRefs {
        pages: pages.clone(),
        tabs: tabs.clone(),
        stack: stack.clone(),
        filter_bar: filter_bar.clone(),
        filter_combo: filter_combo.clone(),
        updating_filter: Rc::new(Cell::new(false)),
        last_tab: Rc::new(RefCell::new(String::new())),
        bars: bars.clone(),
    };

    for tab in Tab::ALL {
        let page = ScrolledWindow::new();
        page.add_css_class("audio-scroll");
        page.set_policy(gtk4::PolicyType::Never, gtk4::PolicyType::Automatic);
        page.set_hexpand(true);
        page.set_vexpand(true);
        stack.add_named(&page, Some(tab.name()));
        pages.borrow_mut().push((tab, page));

        let tab_icon = icon(tab.icon(), "tab-icon");
        let tab_text = label(tab.label(), "tab-text");
        let inner = GtkBox::new(Orientation::Horizontal, 6);
        inner.append(&tab_icon);
        inner.append(&tab_text);
        let tab_button = Button::new();
        tab_button.set_child(Some(&inner));
        tab_button.add_css_class("tab-button");
        tab_button.set_hexpand(true);
        tab_button.set_tooltip_text(Some(tab.label()));

        let refs_c = refs.clone();
        let state_c = state.clone();
        tab_button.connect_clicked(move |_| {
            *state_c.current_tab.borrow_mut() = tab.name().to_string();
            refs_c.stack.set_visible_child_name(tab.name());
            rebuild(&refs_c, &state_c);
        });
        tabs.borrow_mut().push((tab, tab_button.clone(), tab_text));
        tab_bar.append(&tab_button);
    }

    {
        let refs_c = refs.clone();
        let state_c = state.clone();
        filter_combo.connect_selected_notify(move |widget| {
            if refs_c.updating_filter.get() {
                return;
            }
            let tab = Tab::from_name(&state_c.current_tab.borrow());
            if tab.filters().is_empty() {
                return;
            }
            state_c
                .filters
                .borrow_mut()
                .insert(tab.name().to_string(), widget.selected() as usize);
            send(&state_c, AudioCommand::Refresh);
        });
    }

    *state.current_tab.borrow_mut() = Tab::default().name().to_string();
    stack.set_visible_child_name(Tab::default().name());
    rebuild(&refs, &state);

    panel.append(&tab_bar);
    panel.append(&stack);
    panel.append(&filter_bar);

    let refresh_refs = refs.clone();
    let refresh_state = state.clone();
    let refresh = move || rebuild(&refresh_refs, &refresh_state);
    (outer, refresh)
}

fn build_page(tab: Tab, state: &MixerState, audio: &AudioState, bars: &Bars) -> GtkBox {
    let content = GtkBox::new(Orientation::Vertical, 10);
    content.add_css_class("audio-list");
    let filter = state.filter_index(tab.name());

    match tab {
        Tab::Playback => {
            content.append(&label("Aplicaciones reproduciendo", "audio-section"));
            let mut streams: Vec<_> = audio.playback_streams.iter().collect();
            if filter == 0 {
                streams.retain(|s| !s.app_name.is_empty() && s.media_role != "event");
            }
            if streams.is_empty() {
                content.append(&empty_state(
                    "Ninguna aplicación está reproduciendo audio.",
                    "audio-volume-high-symbolic",
                ));
            } else {
                for stream in streams {
                    content.append(&stream_card(
                        state,
                        &stream.app_name,
                        &stream.media_name,
                        stream.icon_name.as_deref(),
                        stream.volume,
                        stream.muted,
                        VolumeTarget::PlaybackStream(stream.index),
                        &stream.channels,
                        bars,
                    ));
                }
            }
        }
        Tab::Record => {
            content.append(&label("Aplicaciones usando el micrófono", "audio-section"));
            let mut streams: Vec<_> = audio.record_streams.iter().collect();
            if filter == 0 {
                streams.retain(|s| !s.app_name.is_empty() && s.media_role != "event");
            }
            if streams.is_empty() {
                content.append(&empty_state(
                    "Ninguna aplicación está grabando audio.",
                    "audio-input-microphone-symbolic",
                ));
            } else {
                for stream in streams {
                    content.append(&stream_card(
                        state,
                        &stream.app_name,
                        &stream.media_name,
                        stream.icon_name.as_deref(),
                        stream.volume,
                        stream.muted,
                        VolumeTarget::RecordStream(stream.index),
                        &stream.channels,
                        bars,
                    ));
                }
            }
        }
        Tab::Output => {
            content.append(&label("Dispositivos de salida", "audio-section"));
            let mut devices: Vec<_> = audio.sinks.iter().collect();
            if filter == 1 {
                devices.retain(|device| device.ports.iter().any(|port| port.available));
            }
            if devices.is_empty() {
                content.append(&empty_state(
                    "No se encontraron dispositivos de salida.",
                    "audio-speakers-symbolic",
                ));
            }
            for device in devices {
                content.append(&device_card(state, device, bars));
            }
        }
        Tab::Input => {
            content.append(&label("Dispositivos de entrada", "audio-section"));
            let mut devices: Vec<_> = audio.sources.iter().collect();
            if filter == 0 {
                devices.retain(|device| !device.is_monitor);
            }
            if devices.is_empty() {
                content.append(&empty_state(
                    "No se encontraron micrófonos.",
                    "audio-input-microphone-symbolic",
                ));
            }
            for device in devices {
                content.append(&source_card(state, device, bars));
            }
        }
        Tab::Config => {
            content.append(&label("Perfiles de sonido", "audio-section"));
            if audio.cards.is_empty() {
                content.append(&empty_state(
                    "No hay tarjetas de sonido.",
                    "preferences-system-symbolic",
                ));
            } else {
                for card in &audio.cards {
                    content.append(&profile_card(state, card));
                }
            }
            content.append(&config_checks(state));
        }
    }
    content
}

fn empty_state(text: &str, icon_name: &str) -> GtkBox {
    let box_ = GtkBox::new(Orientation::Vertical, 10);
    box_.add_css_class("empty-state");
    box_.append(&icon(icon_name, "empty-icon"));
    let message = label(text, "empty-state-text");
    message.set_halign(Align::Center);
    box_.append(&message);
    box_
}

// ── Componente estrella: fill_bar ─────────────────────────────────────────

/// Barra de relleno horizontal sin perilla. `compact` se usa para los canales.
/// Devuelve el contenedor y registra sus referencias para actualizaciones in-place.
#[allow(clippy::too_many_arguments)]
fn fill_bar(
    state: &MixerState,
    target: VolumeTarget,
    volume: f32,
    muted: bool,
    app_icon: &str,
    compact: bool,
    bars: &Bars,
) -> GtkBox {
    let wrapper = GtkBox::new(Orientation::Vertical, 4);
    if !compact {
        wrapper.add_css_class("fill-bar-wrap");
    }

    let scale = Scale::new(Orientation::Horizontal, Some(&Adjustment::new(
        volume.clamp(0.0, 1.5) as f64,
        0.0,
        1.5,
        0.01,
        0.05,
        0.0,
    )));
    scale.set_draw_value(false);
    scale.set_hexpand(true);
    scale.set_can_target(true);
    if volume > 1.0 {
        scale.add_css_class("over-100");
    }
    if compact {
        scale.add_css_class("channel-scale");
    } else {
        scale.add_css_class("fill-bar");
    }

    let updating = Rc::new(Cell::new(false));
    let last_sent = Rc::new(RefCell::new(volume));
    let last_tick = Rc::new(RefCell::new(Instant::now() - Duration::from_millis(200)));
    let timeout_id: Rc<RefCell<Option<glib::SourceId>>> = Rc::new(RefCell::new(None));

    // El valor numérico (cifras tabulares).
    let value_label = label(&percent_text(volume), "bar-value");
    value_label.set_can_target(false);

    let mut mute_image: Option<Image> = None;

    if compact {
        let row = GtkBox::new(Orientation::Horizontal, 10);
        row.append(&scale);
        value_label.add_css_class("channel-value");
        row.append(&value_label);
        wrapper.append(&row);
    } else {
        let overlay = Overlay::new();
        overlay.set_child(Some(&scale));

        // Icono dentro de la barra: clic = mute.
        let icon_name = if muted || volume <= 0.0 {
            "audio-volume-muted-symbolic"
        } else {
            app_icon
        };
        let image = icon(icon_name, "bar-icon-image");
        let mute_button = Button::new();
        mute_button.set_child(Some(&image));
        mute_button.add_css_class("bar-icon");
        mute_button.set_halign(Align::Start);
        mute_button.set_valign(Align::Center);
        mute_button.set_margin_start(8);
        mute_button.set_tooltip_text(Some(if muted { "Activar sonido" } else { "Silenciar" }));
        overlay.add_overlay(&mute_button);
        overlay.set_measure_overlay(&mute_button, false);
        mute_image = Some(image);

        // Porcentaje a la derecha, dentro de la barra.
        value_label.set_halign(Align::End);
        value_label.set_valign(Align::Center);
        value_label.set_margin_end(16);
        overlay.add_overlay(&value_label);
        overlay.set_measure_overlay(&value_label, false);

        // Marca discreta en el 100 % (2/3 del rango 0…1.5).
        let marks = GtkBox::new(Orientation::Horizontal, 0);
        for _ in 0..2 {
            let spacer = GtkBox::new(Orientation::Horizontal, 0);
            spacer.set_hexpand(true);
            marks.append(&spacer);
        }
        let mark = GtkBox::new(Orientation::Horizontal, 0);
        mark.add_css_class("fill-bar-mark");
        mark.set_size_request(2, 9);
        mark.set_valign(Align::End);
        mark.set_margin_bottom(8);
        marks.append(&mark);
        let spacer = GtkBox::new(Orientation::Horizontal, 0);
        spacer.set_hexpand(true);
        marks.append(&spacer);
        marks.set_can_target(false);
        overlay.add_overlay(&marks);
        overlay.set_measure_overlay(&marks, false);

        wrapper.append(&overlay);

        // dB como texto secundario bajo la barra.
        let db = label(&db_text(volume), "bar-db");
        db.set_can_target(false);
        wrapper.append(&db);

        if state.show_meters.get() {
            let line = GtkBox::new(Orientation::Horizontal, 0);
            line.add_css_class("vu-line");
            let fill = GtkBox::new(Orientation::Horizontal, 0);
            fill.add_css_class("vu-line-fill");
            fill.set_size_request((volume.clamp(0.0, 1.5) / 1.5 * 160.0) as i32, 3);
            line.append(&fill);
            wrapper.append(&line);
        }

        let state_mute = state.clone();
        let target_mute = target;
        let muted_now = muted;
        mute_button.connect_clicked(move |_| {
            send(
                &state_mute,
                AudioCommand::SetMute {
                    target: target_mute,
                    muted: !muted_now,
                },
            );
        });
    }

    // Foco: recordamos la barra para devolverlo tras un refresco.
    let focus_controller = gtk4::EventControllerFocus::new();
    let state_focus = state.clone();
    let key_focus = target_key(target);
    focus_controller.connect_enter(move |_| {
        *state_focus.focus_target.borrow_mut() = Some(key_focus.clone());
    });
    scale.add_controller(focus_controller);

    // Arrastre/redactado: throttle de 50 ms + envío final tras 140 ms de calma.
    let state_value = state.clone();
    let channel_values: Vec<f32> = current_channels(state, target, volume);
    let updating_c = updating.clone();
    let value_label_c = value_label.clone();
    let last_sent_c = last_sent.clone();
    let last_tick_c = last_tick.clone();
    let timeout_c = timeout_id.clone();

    scale.connect_value_changed(move |slider| {
        if updating_c.get() {
            return;
        }
        let value = slider.value() as f32;
        if value > 1.0 {
            slider.add_css_class("over-100");
        } else {
            slider.remove_css_class("over-100");
        }
        value_label_c.set_label(&percent_text(value));

        state_value.dragging.set(true);
        *state_value.dragging_target.borrow_mut() = Some(target_key(target));

        if last_tick_c.borrow().elapsed() >= Duration::from_millis(50) {
            *last_tick_c.borrow_mut() = Instant::now();
            *last_sent_c.borrow_mut() = value;
            channels_for(&state_value, target, &channel_values, value);
        }

        if let Some(id) = timeout_c.borrow_mut().take() {
            id.remove();
        }
        let s = state_value.clone();
        let v = value;
        let vals = channel_values.clone();
        let tid = timeout_c.clone();
        let sent = last_sent_c.clone();
        let source = glib::timeout_add_local(Duration::from_millis(140), move || {
            s.dragging.set(false);
            *s.dragging_target.borrow_mut() = None;
            if (v - *sent.borrow()).abs() > 0.001 {
                channels_for(&s, target, &vals, v);
            }
            send(&s, AudioCommand::Refresh);
            *tid.borrow_mut() = None;
            glib::ControlFlow::Break
        });
        *timeout_c.borrow_mut() = Some(source);
    });

    // Las barras de canal comparten objetivo: les damos una clave propia
    // para que no sobrescriban el registro de la barra principal.
    let key = if compact {
        let used = bars
            .borrow()
            .values()
            .filter(|bar| bar.target == target)
            .count();
        format!("{}#ch{used}", target_key(target))
    } else {
        target_key(target)
    };
    bars.borrow_mut().insert(
        key,
        BarRefs {
            target,
            scale,
            value_label: Some(value_label),
            mute_image,
            app_icon: app_icon.to_string(),
            updating,
        },
    );
    wrapper
}

/// Valores de canal actuales del objetivo, para no alterar el balance.
fn current_channels(state: &MixerState, target: VolumeTarget, volume: f32) -> Vec<f32> {
    let audio = state.audio.borrow();
    let found = match target {
        VolumeTarget::Sink(index) => audio
            .sinks
            .iter()
            .find(|d| d.index == index)
            .map(|d| channels(&d.channels)),
        VolumeTarget::Source(index) => audio
            .sources
            .iter()
            .find(|d| d.index == index)
            .map(|d| channels(&d.channels)),
        VolumeTarget::PlaybackStream(index) => audio
            .playback_streams
            .iter()
            .find(|s| s.index == index)
            .map(|s| channels(&s.channels)),
        VolumeTarget::RecordStream(index) => audio
            .record_streams
            .iter()
            .find(|s| s.index == index)
            .map(|s| channels(&s.channels)),
    };
    found.unwrap_or_else(|| vec![volume; 2])
}

// ── Tarjetas ──────────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn stream_card(
    state: &MixerState,
    app: &str,
    media: &str,
    icon_name: Option<&str>,
    volume: f32,
    muted: bool,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
    bars: &Bars,
) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 4);
    card.add_css_class("stream-item");

    let top = GtkBox::new(Orientation::Horizontal, 12);
    top.add_css_class("item-top");
    let name = icon_name
        .filter(|name| !name.is_empty())
        .unwrap_or("audio-volume-high-symbolic");
    top.append(&icon(name, "stream-icon"));
    let title_text = if media.is_empty() {
        app.to_string()
    } else {
        format!("{app} · {media}")
    };
    let title = label(&title_text, "item-title");
    title.set_hexpand(true);
    top.append(&title);
    card.append(&top);

    card.append(&fill_bar(state, target, volume, muted, name, false, bars));
    let _ = channel_info;
    card
}

fn device_card(state: &MixerState, device: &audio_core::SinkInfo, bars: &Bars) -> GtkBox {
    let target = VolumeTarget::Sink(device.index);
    let card = GtkBox::new(Orientation::Vertical, 4);
    card.add_css_class("device-item");
    card.append(&device_top(
        state,
        &device.description,
        &device.name,
        target,
        DeviceType::Sink,
        device.is_default,
    ));
    card.append(&port_combo(
        state,
        DeviceType::Sink,
        device.index,
        &device.ports,
        device.active_port.as_deref(),
    ));
    card.append(&fill_bar(
        state,
        target,
        device.volume,
        device.muted,
        "audio-speakers-symbolic",
        false,
        bars,
    ));
    card.append(&advanced_expander(
        state,
        target,
        &device.channels,
        bars,
    ));
    card
}

fn source_card(state: &MixerState, device: &audio_core::SourceInfo, bars: &Bars) -> GtkBox {
    let target = VolumeTarget::Source(device.index);
    let card = GtkBox::new(Orientation::Vertical, 4);
    card.add_css_class("device-item");
    card.append(&device_top(
        state,
        &device.description,
        &device.name,
        target,
        DeviceType::Source,
        device.is_default,
    ));
    card.append(&port_combo(
        state,
        DeviceType::Source,
        device.index,
        &device.ports,
        device.active_port.as_deref(),
    ));
    card.append(&fill_bar(
        state,
        target,
        device.volume,
        device.muted,
        "audio-input-microphone-symbolic",
        false,
        bars,
    ));
    card.append(&advanced_expander(
        state,
        target,
        &device.channels,
        bars,
    ));
    card
}

fn device_top(
    state: &MixerState,
    display: &str,
    internal: &str,
    target: VolumeTarget,
    kind: DeviceType,
    is_default: bool,
) -> GtkBox {
    let top = GtkBox::new(Orientation::Horizontal, 12);
    top.add_css_class("item-top");
    top.append(&device_icon(display, kind == DeviceType::Source));
    let title = label(display, "item-title");
    title.set_hexpand(true);
    top.append(&title);
    top.append(&default_chip(state, kind, internal, is_default, target));
    top
}

/// Chip único: check verde + candado; un solo clic fija el predeterminado.
fn default_chip(
    state: &MixerState,
    kind: DeviceType,
    internal: &str,
    is_default: bool,
    target: VolumeTarget,
) -> Button {
    let name = if is_default {
        "emblem-ok-symbolic"
    } else {
        "changes-allow-symbolic"
    };
    let inner = GtkBox::new(Orientation::Horizontal, 6);
    inner.append(&icon(name, "chip-icon"));
    inner.append(&label(
        if is_default { "Predeterminado" } else { "Fijar" },
        "chip-text",
    ));
    let chip = Button::new();
    chip.set_child(Some(&inner));
    chip.add_css_class("default-chip");
    if is_default {
        chip.add_css_class("is-default");
        chip.set_tooltip_text(Some("Dispositivo predeterminado"));
    } else {
        chip.set_tooltip_text(Some("Fijar como predeterminado"));
    }
    let state_c = state.clone();
    let device = internal.to_string();
    chip.connect_clicked(move |_| {
        let _ = target; // se conserva por si el chip necesita el objetivo en el futuro
        set_default(&state_c, kind, device.clone());
    });
    chip
}

/// Desplegable "Puerto:" con el estado (desconectado) incluido.
fn port_combo(
    state: &MixerState,
    kind: DeviceType,
    index: u32,
    ports: &[audio_core::PortInfo],
    active_port: Option<&str>,
) -> GtkBox {
    let row = GtkBox::new(Orientation::Horizontal, 8);
    row.add_css_class("field-row");
    row.append(&label("Puerto:", "field-label"));
    if ports.is_empty() {
        row.append(&label("—", "field-value"));
        return row;
    }
    let labels: Vec<String> = ports
        .iter()
        .map(|port| {
            if port.available {
                port.description.clone()
            } else {
                format!("{} (desconectado)", port.description)
            }
        })
        .collect();
    let refs: Vec<&str> = labels.iter().map(|text| text.as_str()).collect();
    let combo = DropDown::from_strings(&refs);
    let active = ports
        .iter()
        .position(|port| Some(port.name.as_str()) == active_port)
        .unwrap_or(0);
    combo.set_selected(active as u32);
    combo.add_css_class("port-combo");
    combo.set_hexpand(true);
    let state_c = state.clone();
    let choices = ports.to_vec();
    combo.connect_selected_notify(move |widget| {
        if let Some(port) = choices.get(widget.selected() as usize) {
            send(
                &state_c,
                AudioCommand::SetPort {
                    device_type: kind,
                    device_index: index,
                    port_name: port.name.clone(),
                },
            );
        }
    });
    row.append(&combo);
    row
}

// ── Opciones avanzadas ────────────────────────────────────────────────────

fn advanced_expander(
    state: &MixerState,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
    bars: &Bars,
) -> gtk4::Expander {
    let expander = gtk4::Expander::new(Some("Opciones avanzadas"));
    expander.add_css_class("advanced-expander");
    expander.set_child(Some(&advanced_content(state, target, channel_info, bars)));
    expander
}

fn advanced_content(
    state: &MixerState,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
    bars: &Bars,
) -> GtkBox {
    let content = GtkBox::new(Orientation::Vertical, 6);
    content.add_css_class("advanced-content");
    let key = target_key(target);
    let unlocked = state.unlocked.borrow().contains(&key);
    let state_link = state.clone();
    let key_link = key.clone();
    content.append(&setting_row("Canales independientes", unlocked, move |active| {
        let mut set = state_link.unlocked.borrow_mut();
        if active {
            set.insert(key_link.clone());
        } else {
            set.remove(&key_link);
        }
        drop(set);
        send(&state_link, AudioCommand::Refresh);
    }));

    for channel in channel_info.iter() {
        let line = GtkBox::new(Orientation::Horizontal, 10);
        line.append(&label(&channel.name, "channel-name"));
        line.append(&fill_bar(
            state,
            target,
            channel.volume,
            false,
            "audio-volume-high-symbolic",
            true,
            bars,
        ));
        content.append(&line);
    }
    content
}

// ── Configuración ─────────────────────────────────────────────────────────

fn profile_card(state: &MixerState, card: &CardInfo) -> GtkBox {
    let item = GtkBox::new(Orientation::Vertical, 4);
    item.add_css_class("device-item");
    let top = GtkBox::new(Orientation::Horizontal, 12);
    top.add_css_class("item-top");
    top.append(&icon("audio-speakers-symbolic", "device-icon"));
    let title = label(&card.description, "item-title");
    title.set_hexpand(true);
    top.append(&title);
    item.append(&top);

    let profiles: Vec<&ProfileInfo> = if state.hide_unavailable.get() {
        card.profiles.iter().filter(|p| p.available).collect()
    } else {
        card.profiles.iter().collect()
    };
    if profiles.is_empty() {
        item.append(&label("No hay perfiles disponibles", "muted-text"));
        return item;
    }

    let labels: Vec<String> = profiles
        .iter()
        .map(|profile| {
            if profile.available {
                profile.description.clone()
            } else {
                format!("{} (no disponible)", profile.description)
            }
        })
        .collect();
    let refs: Vec<&str> = labels.iter().map(|text| text.as_str()).collect();
    let combo = DropDown::from_strings(&refs);
    let active = card
        .active_profile
        .as_deref()
        .and_then(|name| profiles.iter().position(|profile| profile.name == name))
        .unwrap_or(0);
    combo.set_selected(active as u32);
    combo.add_css_class("profile-combo");
    combo.set_hexpand(true);

    let state_c = state.clone();
    let card_index = card.index;
    let choices: Vec<ProfileInfo> = profiles.iter().map(|p| (*p).clone()).collect();
    combo.connect_selected_notify(move |widget| {
        if let Some(profile) = choices.get(widget.selected() as usize) {
            send(
                &state_c,
                AudioCommand::SetCardProfile {
                    card_index,
                    profile_name: profile.name.clone(),
                },
            );
        }
    });

    let row = GtkBox::new(Orientation::Horizontal, 8);
    row.add_css_class("field-row");
    row.append(&label("Perfil:", "field-label"));
    row.append(&combo);
    item.append(&row);
    item
}

/// Fila etiqueta + interruptor estilo One UI.
fn setting_row(text: &str, active: bool, on_change: impl Fn(bool) + 'static) -> GtkBox {
    let row = GtkBox::new(Orientation::Horizontal, 12);
    row.add_css_class("setting-row");
    let caption = label(text, "setting-label");
    caption.set_hexpand(true);
    row.append(&caption);
    let switch = Switch::new();
    switch.add_css_class("oneui-switch");
    switch.set_active(active);
    switch.connect_active_notify(move |widget| on_change(widget.is_active()));
    row.append(&switch);
    row
}

fn config_checks(state: &MixerState) -> GtkBox {
    let box_ = GtkBox::new(Orientation::Vertical, 4);
    box_.add_css_class("config-checks");
    box_.append(&label("Opciones de visualización", "audio-section"));

    let state_meters = state.clone();
    box_.append(&setting_row(
        "Mostrar los medidores de volumen",
        state.show_meters.get(),
        move |active| {
            state_meters.show_meters.set(active);
            send(&state_meters, AudioCommand::Refresh);
        },
    ));

    let state_hide = state.clone();
    box_.append(&setting_row(
        "Ocultar perfiles no disponibles",
        state.hide_unavailable.get(),
        move |active| {
            state_hide.hide_unavailable.set(active);
            send(&state_hide, AudioCommand::Refresh);
        },
    ));
    box_
}
