//! Widgets del mezclador ONE UI: pestañas, filtros, streams, dispositivos y perfiles.

use crate::MixerState;
use audio_core::{AudioCommand, AudioState, CardInfo, DeviceType, ProfileInfo, VolumeTarget};
use gtk4::prelude::*;
use gtk4::{
    Align, Adjustment, Box as GtkBox, Button, CheckButton, DropDown, Image, Label, Orientation,
    Scale, ScrolledWindow, Stack, StringList,
};
use std::{
    cell::{Cell, RefCell},
    rc::Rc,
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

    /// Opciones del selector "Mostrar:". Configuración no lo usa (lleva casillas).
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

// ── Helpers de widgets ────────────────────────────────────────────────────

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

/// Icono del dispositivo según su descripción (altavoz, monitor, micrófono…).
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

fn icon_button(name: &str, class: &str, tooltip: &str) -> Button {
    let widget = Button::new();
    widget.set_child(Some(&icon(name, "button-icon")));
    widget.add_css_class(class);
    widget.set_tooltip_text(Some(tooltip));
    widget
}

fn send(state: &MixerState, command: AudioCommand) {
    state.send(command);
}

fn target_key(target: VolumeTarget) -> String {
    format!("{target:?}")
}

fn db_text(volume: f32) -> String {
    if volume <= 0.000_001 {
        "−∞ dB".into()
    } else {
        format!("{:.2} dB", 60.0 * volume.log10())
    }
}

/// "100% (0.00 dB)" — el formato que pide el diseño.
fn volume_caption(volume: f32) -> String {
    format!(
        "{}% ({})",
        (volume.max(0.0) * 100.0).round() as i32,
        db_text(volume)
    )
}

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

// ── Referencias compartidas de la UI ──────────────────────────────────────

#[derive(Clone)]
struct UiRefs {
    pages: Rc<RefCell<Vec<(Tab, ScrolledWindow)>>>,
    buttons: Rc<RefCell<Vec<(Tab, Button)>>>,
    stack: Stack,
    filter_bar: GtkBox,
    filter_combo: DropDown,
    updating_filter: Rc<Cell<bool>>,
    last_tab: Rc<RefCell<String>>,
}

/// Reconstruye páginas, pestaña activa y barra de filtros.
fn rebuild(refs: &UiRefs, state: &MixerState) {
    let tab = Tab::from_name(&state.current_tab.borrow());
    let snapshot = state.audio.borrow().clone();

    for (item, page) in refs.pages.borrow().iter() {
        page.set_child(Some(&build_page(*item, state, &snapshot)));
    }
    for (item, button) in refs.buttons.borrow().iter() {
        if *item == tab {
            button.add_css_class("active");
        } else {
            button.remove_css_class("active");
        }
    }

    let options = tab.filters();
    refs.filter_bar.set_visible(!options.is_empty());
    // Solo reconstruimos el desplegable al cambiar de pestaña: así no se cierra
    // mientras el usuario está eligiendo una opción.
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

    let pages: Rc<RefCell<Vec<(Tab, ScrolledWindow)>>> = Rc::new(RefCell::new(Vec::new()));
    let buttons: Rc<RefCell<Vec<(Tab, Button)>>> = Rc::new(RefCell::new(Vec::new()));

    // Barra inferior fija "Mostrar:"
    let filter_bar = GtkBox::new(Orientation::Horizontal, 10);
    filter_bar.add_css_class("filter-bar");
    filter_bar.append(&label("Mostrar:", "filter-label"));
    let filter_combo = DropDown::from_strings(Tab::default().filters());
    filter_combo.add_css_class("filter-combo");
    filter_bar.append(&filter_combo);

    let refs = UiRefs {
        pages: pages.clone(),
        buttons: buttons.clone(),
        stack: stack.clone(),
        filter_bar: filter_bar.clone(),
        filter_combo: filter_combo.clone(),
        updating_filter: Rc::new(Cell::new(false)),
        last_tab: Rc::new(RefCell::new(String::new())),
    };

    for tab in Tab::ALL {
        let page = ScrolledWindow::new();
        page.add_css_class("audio-scroll");
        page.set_policy(gtk4::PolicyType::Never, gtk4::PolicyType::Automatic);
        page.set_hexpand(true);
        page.set_vexpand(true);
        stack.add_named(&page, Some(tab.name()));
        pages.borrow_mut().push((tab, page));

        let inner = GtkBox::new(Orientation::Horizontal, 6);
        inner.append(&icon(tab.icon(), "tab-icon"));
        inner.append(&label(tab.label(), "tab-text"));
        let tab_button = Button::new();
        tab_button.set_child(Some(&inner));
        tab_button.add_css_class("tab-button");
        tab_button.set_hexpand(true);

        let refs_c = refs.clone();
        let state_c = state.clone();
        tab_button.connect_clicked(move |_| {
            *state_c.current_tab.borrow_mut() = tab.name().to_string();
            refs_c.stack.set_visible_child_name(tab.name());
            rebuild(&refs_c, &state_c);
        });
        buttons.borrow_mut().push((tab, tab_button.clone()));
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

    *state.current_tab.borrow_mut() = Tab::Playback.name().to_string();
    stack.set_visible_child_name(Tab::Playback.name());
    rebuild(&refs, &state);

    panel.append(&tab_bar);
    panel.append(&stack);
    panel.append(&filter_bar);

    let refresh_refs = refs.clone();
    let refresh_state = state.clone();
    let refresh = move || rebuild(&refresh_refs, &refresh_state);
    (outer, refresh)
}

fn build_page(tab: Tab, state: &MixerState, audio: &AudioState) -> GtkBox {
    let content = GtkBox::new(Orientation::Vertical, 10);
    content.add_css_class("audio-list");
    let filter = state.filter_index(tab.name());

    match tab {
        Tab::Playback => {
            content.append(&label("Aplicaciones reproduciendo", "audio-section"));
            let mut streams: Vec<_> = audio.playback_streams.iter().collect();
            if filter == 0 {
                streams.retain(|stream| {
                    !stream.app_name.is_empty() && stream.media_role != "event"
                });
            }
            if streams.is_empty() {
                content.append(&empty_state("Ninguna aplicación está reproduciendo audio."));
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
                    ));
                }
            }
        }
        Tab::Record => {
            content.append(&label("Aplicaciones usando el micrófono", "audio-section"));
            let mut streams: Vec<_> = audio.record_streams.iter().collect();
            if filter == 0 {
                streams.retain(|stream| {
                    !stream.app_name.is_empty() && stream.media_role != "event"
                });
            }
            if streams.is_empty() {
                content.append(&empty_state("Ninguna aplicación está grabando audio."));
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
                content.append(&empty_state("No se encontraron dispositivos de salida."));
            }
            for device in devices {
                content.append(&device_card(state, device));
            }
        }
        Tab::Input => {
            content.append(&label("Dispositivos de entrada", "audio-section"));
            let mut devices: Vec<_> = audio.sources.iter().collect();
            if filter == 0 {
                devices.retain(|device| !device.is_monitor);
            }
            if devices.is_empty() {
                content.append(&empty_state("No se encontraron micrófonos."));
            }
            for device in devices {
                content.append(&source_card(state, device));
            }
        }
        Tab::Config => {
            content.append(&label("Perfiles de sonido", "audio-section"));
            if audio.cards.is_empty() {
                content.append(&empty_state("No hay tarjetas de sonido."));
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

fn empty_state(text: &str) -> GtkBox {
    let box_ = GtkBox::new(Orientation::Vertical, 8);
    box_.add_css_class("empty-state");
    let message = label(text, "empty-state-text");
    message.set_halign(Align::Center);
    message.set_valign(Align::Center);
    box_.append(&message);
    box_
}

// ── Filas de aplicaciones ─────────────────────────────────────────────────

fn stream_card(
    state: &MixerState,
    app: &str,
    media: &str,
    icon_name: Option<&str>,
    volume: f32,
    muted: bool,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("stream-item");

    let top = GtkBox::new(Orientation::Horizontal, 10);
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
    top.append(&mute_button(state, target, muted, volume));
    card.append(&top);

    card.append(&volume_slider(state, target, volume, &channels(channel_info)));
    card
}

// ── Filas de dispositivos ─────────────────────────────────────────────────

fn device_top(
    state: &MixerState,
    display: &str,
    internal: &str,
    target: VolumeTarget,
    kind: DeviceType,
    muted: bool,
    volume: f32,
    is_default: bool,
    source: bool,
) -> GtkBox {
    let top = GtkBox::new(Orientation::Horizontal, 10);
    top.add_css_class("item-top");
    top.append(&device_icon(display, source));
    let title = label(display, "item-title");
    title.set_hexpand(true);
    top.append(&title);
    top.append(&mute_button(state, target, muted, volume));
    top.append(&lock_button(state, kind, internal, is_default));
    top.append(&default_check(is_default));
    top
}

fn device_card(state: &MixerState, device: &audio_core::SinkInfo) -> GtkBox {
    let target = VolumeTarget::Sink(device.index);
    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("device-item");
    card.append(&device_top(
        state,
        &device.description,
        &device.name,
        target,
        DeviceType::Sink,
        device.muted,
        device.volume,
        device.is_default,
        false,
    ));
    card.append(&port_combo(
        state,
        DeviceType::Sink,
        device.index,
        &device.ports,
        device.active_port.as_deref(),
    ));
    card.append(&volume_slider(
        state,
        target,
        device.volume,
        &channels(&device.channels),
    ));
    card.append(&advanced_expander(
        state,
        target,
        device.index,
        DeviceType::Sink,
        &device.channels,
        &device.ports,
    ));
    card
}

fn source_card(state: &MixerState, device: &audio_core::SourceInfo) -> GtkBox {
    let target = VolumeTarget::Source(device.index);
    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("device-item");
    card.append(&device_top(
        state,
        &device.description,
        &device.name,
        target,
        DeviceType::Source,
        device.muted,
        device.volume,
        device.is_default,
        true,
    ));
    card.append(&port_combo(
        state,
        DeviceType::Source,
        device.index,
        &device.ports,
        device.active_port.as_deref(),
    ));
    card.append(&volume_slider(
        state,
        target,
        device.volume,
        &channels(&device.channels),
    ));
    card.append(&advanced_expander(
        state,
        target,
        device.index,
        DeviceType::Source,
        &device.channels,
        &device.ports,
    ));
    card
}

fn mute_button(state: &MixerState, target: VolumeTarget, muted: bool, volume: f32) -> Button {
    let name = if muted || volume <= 0.0 {
        "audio-volume-muted-symbolic"
    } else {
        "audio-volume-high-symbolic"
    };
    let tooltip = if muted { "Activar sonido" } else { "Silenciar" };
    let button = icon_button(name, "mute-button", tooltip);
    let state_c = state.clone();
    button.connect_clicked(move |_| {
        send(
            &state_c,
            AudioCommand::SetMute {
                target,
                muted: !muted,
            },
        );
    });
    button
}

/// Candado: fija el dispositivo como predeterminado.
fn lock_button(
    state: &MixerState,
    kind: DeviceType,
    internal: &str,
    is_default: bool,
) -> Button {
    let name = if is_default {
        "changes-prevent-symbolic"
    } else {
        "changes-allow-symbolic"
    };
    let tooltip = if is_default {
        "Dispositivo predeterminado"
    } else {
        "Fijar como predeterminado"
    };
    let button = icon_button(name, "lock-button", tooltip);
    let state_c = state.clone();
    let device = internal.to_string();
    button.connect_clicked(move |_| set_default(&state_c, kind, device.clone()));
    button
}

/// Check verde que marca el dispositivo activo.
fn default_check(is_default: bool) -> GtkBox {
    let slot = GtkBox::new(Orientation::Horizontal, 0);
    slot.add_css_class("check-slot");
    if is_default {
        slot.append(&icon("emblem-ok-symbolic", "default-check"));
        slot.add_css_class("is-default");
    }
    slot
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

// ── Slider compartido ─────────────────────────────────────────────────────

fn volume_slider(
    state: &MixerState,
    target: VolumeTarget,
    volume: f32,
    channel_values: &[f32],
) -> GtkBox {
    let row = GtkBox::new(Orientation::Horizontal, 10);
    row.add_css_class("slider-row");

    row.append(&label("Silencio", "slider-caption"));

    let scale = Scale::new(Orientation::Horizontal, Some(&Adjustment::new(
        volume.clamp(0.0, 1.5) as f64,
        0.0,
        1.5,
        0.01,
        0.05,
        0.0,
    )));
    scale.add_css_class("volume-scale");
    scale.set_draw_value(false);
    scale.set_hexpand(true);
    let state_c = state.clone();
    let values = channel_values.to_vec();
    scale.connect_value_changed(move |slider| {
        channels_for(&state_c, target, &values, slider.value() as f32)
    });
    row.append(&scale);

    let value = label(&volume_caption(volume), "volume-caption");
    value.set_width_chars(17);
    value.set_xalign(1.0);
    row.append(&value);

    let wrapper = GtkBox::new(Orientation::Vertical, 4);
    wrapper.append(&row);
    if state.show_meters.get() {
        let meter = GtkBox::new(Orientation::Horizontal, 0);
        meter.add_css_class("vu-meter");
        let fill = GtkBox::new(Orientation::Horizontal, 0);
        fill.add_css_class("vu-meter-fill");
        fill.set_size_request((volume.clamp(0.0, 1.5) / 1.5 * 160.0) as i32, 4);
        meter.append(&fill);
        wrapper.append(&meter);
    }
    wrapper
}

// ── Opciones avanzadas ────────────────────────────────────────────────────

fn advanced_expander(
    state: &MixerState,
    target: VolumeTarget,
    _index: u32,
    _kind: DeviceType,
    channel_info: &[audio_core::ChannelInfo],
    _ports: &[audio_core::PortInfo],
) -> gtk4::Expander {
    let expander = gtk4::Expander::new(Some("Opciones avanzadas"));
    expander.add_css_class("advanced-expander");
    expander.set_child(Some(&advanced_content(state, target, channel_info)));
    expander
}

fn advanced_content(
    state: &MixerState,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
) -> GtkBox {
    let content = GtkBox::new(Orientation::Vertical, 8);
    content.add_css_class("advanced-content");

    let key = target_key(target);
    let unlocked = state.unlocked.borrow().contains(&key);
    let link = CheckButton::with_label("Canales independientes");
    link.set_active(unlocked);
    let state_c = state.clone();
    let key_c = key.clone();
    link.connect_toggled(move |widget| {
        let mut set = state_c.unlocked.borrow_mut();
        if widget.is_active() {
            set.insert(key_c.clone());
        } else {
            set.remove(&key_c);
        }
        drop(set);
        send(&state_c, AudioCommand::Refresh);
    });
    content.append(&link);

    for (position, channel) in channel_info.iter().enumerate() {
        content.append(&channel_slider(
            state,
            target,
            channel_info,
            position,
            &channel.name,
            channel.volume,
        ));
    }
    content
}

fn channel_slider(
    state: &MixerState,
    target: VolumeTarget,
    channel_info: &[audio_core::ChannelInfo],
    channel: usize,
    name: &str,
    volume: f32,
) -> GtkBox {
    let line = GtkBox::new(Orientation::Horizontal, 10);
    line.append(&label(name, "channel-name"));
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
    scale.add_css_class("channel-scale");
    let state_c = state.clone();
    let values = channels(channel_info);
    scale.connect_value_changed(move |slider| {
        let mut updated = values.to_vec();
        if let Some(value) = updated.get_mut(channel) {
            *value = slider.value() as f32;
        }
        send(
            &state_c,
            AudioCommand::SetChannelVolumes {
                target,
                channels: updated,
            },
        );
    });
    line.append(&scale);
    line.append(&label(&format!("{:.0}%", volume * 100.0), "channel-value"));
    line
}

// ── Configuración ─────────────────────────────────────────────────────────

fn profile_card(state: &MixerState, card: &CardInfo) -> GtkBox {
    let item = GtkBox::new(Orientation::Vertical, 10);
    item.add_css_class("device-item");

    let top = GtkBox::new(Orientation::Horizontal, 10);
    top.add_css_class("item-top");
    top.append(&icon("audio-speakers-symbolic", "device-icon"));
    let title = label(&card.description, "item-title");
    title.set_hexpand(true);
    top.append(&title);
    item.append(&top);

    let profiles: Vec<&ProfileInfo> = if state.hide_unavailable.get() {
        card.profiles.iter().filter(|profile| profile.available).collect()
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
    let choices: Vec<ProfileInfo> = profiles.iter().map(|profile| (*profile).clone()).collect();
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

fn config_checks(state: &MixerState) -> GtkBox {
    let box_ = GtkBox::new(Orientation::Vertical, 6);
    box_.add_css_class("config-checks");
    box_.append(&label("Opciones de visualización", "audio-section"));

    let meters = CheckButton::with_label("Mostrar los medidores de volumen");
    meters.set_active(state.show_meters.get());
    let state_meters = state.clone();
    meters.connect_toggled(move |widget| {
        state_meters.show_meters.set(widget.is_active());
        send(&state_meters, AudioCommand::Refresh);
    });
    box_.append(&meters);

    let hide = CheckButton::with_label("Hide unavailable card profiles");
    hide.set_active(state.hide_unavailable.get());
    let state_hide = state.clone();
    hide.connect_toggled(move |widget| {
        state_hide.hide_unavailable.set(widget.is_active());
        send(&state_hide, AudioCommand::Refresh);
    });
    box_.append(&hide);
    box_
}
