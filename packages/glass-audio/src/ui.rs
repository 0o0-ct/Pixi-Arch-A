//! Widgets del mezclador ONE UI: pestañas funcionales, tarjetas de dispositivo,
//! controles de volumen y opciones avanzadas.

use audio_core::{AudioCommand, AudioState, DeviceType, VolumeTarget};
use gtk4::prelude::*;
use gtk4::{
    Align, Adjustment, Box as GtkBox, Button, DropDown, Label, Orientation, Scale,
    ScrolledWindow, Stack,
};
use std::{cell::RefCell, rc::Rc};
use crate::MixerState;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Tab { Output, Input, Playback, Record, Config }
impl Tab {
    const ALL: [Tab; 5] = [Tab::Output, Tab::Input, Tab::Playback, Tab::Record, Tab::Config];
    fn name(self) -> &'static str { match self { Self::Output=>"output",Self::Input=>"input",Self::Playback=>"playback",Self::Record=>"record",Self::Config=>"config" } }
    fn label(self) -> &'static str { match self { Self::Output=>"Salida",Self::Input=>"Entrada",Self::Playback=>"Reproducción",Self::Record=>"Grabación",Self::Config=>"Configuración" } }
    fn glyph(self) -> &'static str { match self { Self::Output=>"♫",Self::Input=>"♩",Self::Playback=>"▶",Self::Record=>"●",Self::Config=>"⚙" } }
}

fn label(text: &str, class: &str) -> Label {
    let widget = Label::new(Some(text));
    widget.add_css_class(class);
    widget
}
fn button(text: &str, class: &str) -> Button {
    let widget = Button::with_label(text);
    widget.add_css_class(class);
    widget
}
fn send(state: &MixerState, command: AudioCommand) { state.send(command); }
fn target_key(target: VolumeTarget) -> String { format!("{target:?}") }
fn volume_text(volume: f32) -> String {
    let percent = (volume.max(0.0) * 100.0).round() as i32;
    let db = if volume <= 0.000_001 { "−∞ dB".into() } else { format!("{:.2} dB", 60.0 * volume.log10()) };
    format!("{percent}% · {db}")
}
fn channels_for(state: &MixerState, target: VolumeTarget, current: &[f32], volume: f32) {
    if !state.unlocked.borrow().contains(&target_key(target)) || current.is_empty() {
        send(state, AudioCommand::SetVolume { target, volume, channels: current.len().max(1) });
        return;
    }
    let average = current.iter().copied().sum::<f32>() / current.len() as f32;
    let values = if average <= f32::EPSILON {
        vec![volume; current.len()]
    } else {
        current.iter().map(|channel| (channel * volume / average).clamp(0.0, 1.5)).collect()
    };
    send(state, AudioCommand::SetChannelVolumes { target, channels: values });
}
fn channels(volume: &[audio_core::ChannelInfo]) -> Vec<f32> { volume.iter().map(|channel| channel.volume).collect() }
fn set_default(state: &MixerState, device_type: DeviceType, name: String) {
    send(state, AudioCommand::SetDefault { device_type, name });
}

pub fn build_mixer(state: MixerState, window: gtk4::ApplicationWindow) -> (GtkBox, impl Fn() + 'static) {
    let outer = GtkBox::new(Orientation::Vertical, 0);
    outer.add_css_class("audio-shell");
    let panel = GtkBox::new(Orientation::Vertical, 0);
    panel.add_css_class("audio-panel");
    panel.set_hexpand(true);
    panel.set_vexpand(true);
    outer.append(&panel);

    let header = GtkBox::new(Orientation::Horizontal, 12);
    header.add_css_class("audio-header");
    let heading = GtkBox::new(Orientation::Vertical, 2);
    heading.set_hexpand(true);
    heading.append(&label("Sonido", "audio-title"));
    let server = state.audio.borrow().server_name.clone();
    heading.append(&label(if server.is_empty() { "PipeWire" } else { &server }, "audio-subtitle"));
    header.append(&heading);
    let close = button("×", "round-action");
    close.set_tooltip_text(Some("Cerrar"));
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
    for tab in Tab::ALL {
        let page = ScrolledWindow::new();
        page.add_css_class("audio-scroll");
        page.set_policy(gtk4::PolicyType::Never, gtk4::PolicyType::Automatic);
        page.set_hexpand(true);
        page.set_vexpand(true);
        stack.add_named(&page, Some(tab.name()));
        pages.borrow_mut().push((tab, page));

        let tab_button = button(&format!("{}  {}", tab.glyph(), tab.label()), "tab-button");
        let stack_c = stack.clone();
        let pages_c = pages.clone();
        let buttons_c = buttons.clone();
        let state_c = state.clone();
        tab_button.connect_clicked(move |_| {
            stack_c.set_visible_child_name(tab.name());
            for (item, button) in buttons_c.borrow().iter() {
                if *item == tab { button.add_css_class("active"); } else { button.remove_css_class("active"); }
            }
            let audio = state_c.audio.borrow().clone();
            if let Some((_, page)) = pages_c.borrow().iter().find(|(item, _)| *item == tab) {
                page.set_child(Some(&build_page(tab, &state_c, &audio)));
            }
        });
        buttons.borrow_mut().push((tab, tab_button.clone()));
        tab_bar.append(&tab_button);
    }
    panel.append(&tab_bar);
    panel.append(&stack);

    for (tab, page) in pages.borrow().iter() {
        page.set_child(Some(&build_page(*tab, &state, &state.audio.borrow())));
    }
    stack.set_visible_child_name("output");
    if let Some((_, active)) = buttons.borrow().iter().find(|(tab, _)| *tab == Tab::Output) { active.add_css_class("active"); }

    let refresh_pages = pages.clone();
    let refresh_buttons = buttons.clone();
    let refresh_stack = stack.clone();
    let refresh_state = state.clone();
    let refresh: Box<dyn Fn()> = Box::new(move || {
        let snapshot = refresh_state.audio.borrow().clone();
        let visible = refresh_stack.visible_child_name().map(|name| name.to_string()).unwrap_or_else(|| "output".into());
        for (tab, page) in refresh_pages.borrow().iter() {
            page.set_child(Some(&build_page(*tab, &refresh_state, &snapshot)));
        }
        for (tab, tab_button) in refresh_buttons.borrow().iter() {
            if tab.name() == visible { tab_button.add_css_class("active"); } else { tab_button.remove_css_class("active"); }
        }
    });
    (outer, move || refresh())
}

fn build_page(tab: Tab, state: &MixerState, audio: &AudioState) -> GtkBox {
    let content = GtkBox::new(Orientation::Vertical, 12);
    content.add_css_class("audio-list");
    match tab {
        Tab::Output => {
            content.append(&label("Dispositivos de salida", "audio-section"));
            let mut devices: Vec<_> = audio.sinks.iter().collect();
            if !state.show_all.get() { devices.retain(|device| device.ports.iter().any(|port| port.available)); }
            for device in devices { content.append(&device_card(state, device, VolumeTarget::Sink(device.index), DeviceType::Sink)); }
            let toggle = button(if state.show_all.get() { "Mostrar: Todos los dispositivos de salida  ⌄" } else { "Mostrar: Disponibles  ⌄" }, "filter-chip");
            let show_all = state.show_all.clone();
            let state_c = state.clone();
            toggle.connect_clicked(move |_| { show_all.set(!show_all.get()); send(&state_c, AudioCommand::Refresh); });
            toggle.set_halign(Align::Center);
            content.append(&toggle);
            if audio.sinks.is_empty() { content.append(&empty_state("No se encontraron dispositivos de salida")); }
        }
        Tab::Input => {
            content.append(&label("Dispositivos de entrada", "audio-section"));
            let sources: Vec<_> = audio.sources.iter().filter(|source| !source.is_monitor).collect();
            for device in sources { content.append(&source_card(state, device)); }
            if audio.sources.iter().all(|source| source.is_monitor) { content.append(&empty_state("No se encontraron micrófonos")); }
        }
        Tab::Playback => {
            content.append(&label("Aplicaciones reproduciendo", "audio-section"));
            for stream in &audio.playback_streams { content.append(&stream_card(state, &stream.app_name, &stream.media_name, stream.volume, stream.muted, stream.index, VolumeTarget::PlaybackStream(stream.index), &stream.channels)); }
            if audio.playback_streams.is_empty() { content.append(&empty_state("No hay aplicaciones reproduciendo audio")); }
        }
        Tab::Record => {
            content.append(&label("Aplicaciones usando el micrófono", "audio-section"));
            for stream in &audio.record_streams { content.append(&stream_card(state, &stream.app_name, &stream.media_name, stream.volume, stream.muted, stream.index, VolumeTarget::RecordStream(stream.index), &stream.channels)); }
            if audio.record_streams.is_empty() { content.append(&empty_state("Ninguna aplicación está grabando")); }
        }
        Tab::Config => {
            content.append(&label("Perfiles de sonido", "audio-section"));
            for card in &audio.cards {
                let item = GtkBox::new(Orientation::Vertical, 10);
                item.add_css_class("audio-card");
                item.append(&label(&card.description, "card-name"));
                let profiles: Vec<_> = card.profiles.iter().filter(|profile| profile.available).collect();
                if profiles.is_empty() { item.append(&label("No hay perfiles disponibles", "muted-text")); }
                for profile in profiles {
                    let selected = card.active_profile.as_deref() == Some(profile.name.as_str());
                    let button = button(&format!("{}  {}", if selected { "●" } else { "○" }, profile.description), "option-row");
                    let state_c = state.clone();
                    let card_index = card.index;
                    let profile_name = profile.name.clone();
                    button.connect_clicked(move |_| send(&state_c, AudioCommand::SetCardProfile { card_index, profile_name: profile_name.clone() }));
                    item.append(&button);
                }
                content.append(&item);
            }
            if audio.cards.is_empty() { content.append(&empty_state("No hay tarjetas de sonido")); }
        }
    }
    content
}

fn empty_state(text: &str) -> GtkBox {
    let box_ = GtkBox::new(Orientation::Vertical, 8);
    box_.add_css_class("empty-state");
    box_.append(&label("♫", "empty-icon"));
    box_.append(&label(text, "muted-text"));
    box_
}

fn device_card(state: &MixerState, device: &audio_core::SinkInfo, target: VolumeTarget, kind: DeviceType) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 12);
    card.add_css_class("audio-card");
    let head = GtkBox::new(Orientation::Horizontal, 12);
    head.add_css_class("card-head");
    head.append(&label("♫", "device-icon"));
    let names = GtkBox::new(Orientation::Vertical, 5);
    names.set_hexpand(true);
    names.append(&label(&device.description, "card-name"));
    if let Some(port) = device.ports.iter().find(|port| Some(port.name.as_str()) == device.active_port.as_deref()) {
        let available = if port.available { "" } else { " · desconectado" };
        let ports: Vec<_> = device.ports.iter().map(|item| item.description.clone()).collect();
        let port_button = button(&format!("⌁  {}{}  ⌄", port.description, available), "port-chip");
        port_button.set_sensitive(!ports.is_empty());
        let state_c = state.clone();
        let index = device.index;
        let current = port.name.clone();
        let choices = device.ports.clone();
        port_button.connect_clicked(move |_| {
            if choices.is_empty() { return; }
            let current_index = choices.iter().position(|item| item.name == current).unwrap_or(0);
            let next = &choices[(current_index + 1) % choices.len()];
            send(&state_c, AudioCommand::SetPort { device_type: kind, device_index: index, port_name: next.name.clone() });
        });
        names.append(&port_button);
    } else if !device.ports.is_empty() {
        let names_: Vec<_> = device.ports.iter().map(|port| port.description.as_str()).collect();
        names.append(&label(&names_.join(" · "), "port-chip-label"));
    }
    head.append(&names);
    let selected = button(if device.is_default { "✓" } else { "○" }, if device.is_default { "default-selected" } else { "default-button" });
    selected.set_tooltip_text(Some(if device.is_default { "Dispositivo predeterminado" } else { "Usar como predeterminado" }));
    let state_default = state.clone();
    let name = device.name.clone();
    selected.connect_clicked(move |_| set_default(&state_default, kind, name.clone()));
    head.append(&selected);
    card.append(&head);
    card.append(&volume_row(state, target, device.volume, device.muted, &channels(&device.channels), device.is_default));
    let advanced = gtk4::Expander::new(Some("Opciones avanzadas"));
    advanced.add_css_class("advanced-expander");
    advanced.set_child(Some(&advanced_device_controls(state, target, device.index, kind, &device.channels, &device.ports)));
    card.append(&advanced);
    card
}

fn source_card(state: &MixerState, device: &audio_core::SourceInfo) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 12);
    card.add_css_class("audio-card");
    let head = GtkBox::new(Orientation::Horizontal, 12);
    head.append(&label("♩", "device-icon"));
    head.append(&label(&device.description, "card-name"));
    let default = button(if device.is_default { "✓" } else { "○" }, if device.is_default { "default-selected" } else { "default-button" });
    let state_c = state.clone();
    let name = device.name.clone();
    default.connect_clicked(move |_| set_default(&state_c, DeviceType::Source, name.clone()));
    head.append(&default);
    card.append(&head);
    card.append(&volume_row(state, VolumeTarget::Source(device.index), device.volume, device.muted, &channels(&device.channels), false));
    let advanced = gtk4::Expander::new(Some("Opciones avanzadas"));
    advanced.add_css_class("advanced-expander");
    advanced.set_child(Some(&advanced_device_controls(state, VolumeTarget::Source(device.index), device.index, DeviceType::Source, &device.channels, &device.ports)));
    card.append(&advanced);
    card
}

fn stream_card(state: &MixerState, app: &str, media: &str, volume: f32, muted: bool, index: u32, target: VolumeTarget, channel_info: &[audio_core::ChannelInfo]) -> GtkBox {
    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("audio-card");
    card.append(&label(if media.is_empty() { app } else { &format!("{app} · {media}") }, "card-name"));
    card.append(&volume_row(state, target, volume, muted, &channels(channel_info), false));
    let advanced = gtk4::Expander::new(Some("Opciones avanzadas"));
    advanced.add_css_class("advanced-expander");
    advanced.set_child(Some(&advanced_stream_controls(state, target, index, channel_info)));
    card.append(&advanced);
    card
}

fn volume_row(state: &MixerState, target: VolumeTarget, volume: f32, muted: bool, channel_values: &[f32], default_marker: bool) -> GtkBox {
    let row = GtkBox::new(Orientation::Horizontal, 12);
    row.add_css_class("volume-row");
    let pill = GtkBox::new(Orientation::Horizontal, 8);
    pill.add_css_class("volume-pill");
    pill.set_hexpand(true);
    let mute = button(if muted || volume <= 0.0 { "◖×" } else { "◖))" }, "volume-mute");
    mute.set_tooltip_text(Some(if muted { "Activar sonido" } else { "Silenciar" }));
    let target_for_mute = target;
    let state_mute = state.clone();
    let muted_now = muted;
    mute.connect_clicked(move |_| send(&state_mute, AudioCommand::SetMute { target: target_for_mute, muted: !muted_now }));
    pill.append(&mute);

    let scale = Scale::new(Orientation::Horizontal, Some(&Adjustment::new(volume.clamp(0.0, 1.5) as f64, 0.0, 1.5, 0.01, 0.05, 0.0)));
    scale.add_css_class("volume-scale");
    scale.set_draw_value(false);
    scale.set_hexpand(true);
    scale.set_value_pos(gtk4::PositionType::Bottom);
    let state_volume = state.clone();
    let values = channel_values.to_vec();
    scale.connect_value_changed(move |slider| channels_for(&state_volume, target, &values, slider.value() as f32));
    pill.append(&scale);
    let value = label(&volume_text(volume), "volume-value");
    value.set_width_chars(17);
    value.set_xalign(1.0);
    pill.append(&value);
    if default_marker { pill.add_css_class("has-default-marker"); }
    row.append(&pill);

    let key = target_key(target);
    let unlocked = state.unlocked.borrow().contains(&key);
    let lock = button(if unlocked { "♧" } else { "♙" }, "lock-button");
    lock.set_tooltip_text(Some(if unlocked { "Canales independientes (clic para enlazar)" } else { "Canales enlazados (clic para separar)" }));
    let linked_set = state.unlocked.clone();
    let key_c = key.clone();
    let state_refresh = state.clone();
    lock.connect_clicked(move |_| {
        let mut set = linked_set.borrow_mut();
        if !set.insert(key_c.clone()) { set.remove(&key_c); }
        drop(set);
        send(&state_refresh, AudioCommand::Refresh);
    });
    row.append(&lock);

    let vu = GtkBox::new(Orientation::Horizontal, 0);
    vu.add_css_class("vu-meter");
    let vu_fill = GtkBox::new(Orientation::Horizontal, 0);
    vu_fill.add_css_class("vu-meter-fill");
    vu_fill.set_size_request((volume.clamp(0.0, 1.5) / 1.5 * 160.0) as i32, 3);
    vu.append(&vu_fill);
    let wrapper = GtkBox::new(Orientation::Vertical, 4);
    wrapper.append(&row);
    wrapper.append(&vu);
    wrapper.set_margin_bottom(2);
    wrapper.add_css_class("volume-control");
    wrapper
}

fn advanced_device_controls(state: &MixerState, target: VolumeTarget, index: u32, kind: DeviceType, channel_info: &[audio_core::ChannelInfo], ports: &[audio_core::PortInfo]) -> GtkBox {
    let advanced = GtkBox::new(Orientation::Vertical, 8);
    advanced.add_css_class("advanced-content");
    for (i, channel) in channel_info.iter().enumerate() {
        advanced.append(&channel_slider(state, target, channel_info, i, &channel.name, channel.volume));
    }
    if !ports.is_empty() {
        advanced.append(&label("Conectores", "advanced-label"));
        for port in ports {
            let status = if port.available { "Disponible" } else { "Desconectado" };
            let row = button(&format!("{}  ·  {}", port.description, status), "option-row");
            let state_c = state.clone();
            let name = port.name.clone();
            row.connect_clicked(move |_| send(&state_c, AudioCommand::SetPort { device_type: kind, device_index: index, port_name: name.clone() }));
            row.set_sensitive(port.available);
            advanced.append(&row);
        }
    }
    let _ = target;
    advanced
}

fn advanced_stream_controls(state: &MixerState, target: VolumeTarget, _index: u32, channel_info: &[audio_core::ChannelInfo]) -> GtkBox {
    let advanced = GtkBox::new(Orientation::Vertical, 8);
    advanced.add_css_class("advanced-content");
    for (i, channel) in channel_info.iter().enumerate() {
        advanced.append(&channel_slider(state, target, channel_info, i, &channel.name, channel.volume));
    }
    advanced
}

fn channel_slider(state: &MixerState, target: VolumeTarget, channel_info: &[audio_core::ChannelInfo], channel: usize, name: &str, volume: f32) -> GtkBox {
    let line = GtkBox::new(Orientation::Horizontal, 10);
    line.append(&label(name, "channel-name"));
    let scale = Scale::new(Orientation::Horizontal, Some(&Adjustment::new(volume.clamp(0.0, 1.5) as f64, 0.0, 1.5, 0.01, 0.05, 0.0)));
    scale.set_draw_value(false);
    scale.set_hexpand(true);
    scale.add_css_class("channel-scale");
    let state_c = state.clone();
    let mut values = channels(channel_info);
    scale.connect_value_changed(move |slider| {
        if let Some(value) = values.get_mut(channel) { *value = slider.value() as f32; }
        send(&state_c, AudioCommand::SetChannelVolumes { target, channels: values.clone() });
    });
    line.append(&scale);
    let val = label(&format!("{:.0}%", volume * 100.0), "channel-value");
    line.append(&val);
    line
}

#[allow(dead_code)]
fn _profile_dropdown(labels: &[String]) -> Option<DropDown> {
    if labels.is_empty() { None } else { Some(DropDown::from_strings(labels)) }
}
