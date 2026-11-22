//! # glass-audio v2 - UI Builders
//!
//! Construcción de todos los componentes visuales del Quick Settings.

use gtk4::prelude::*;
use gtk4::{
    Adjustment, Box as GtkBox, Button, Grid, Image, Label, Orientation, Scale,
};

use std::rc::Rc;

use crate::QuickSettingsState;

/// Smart Device info
#[derive(Clone, Debug)]
pub struct SmartDevice {
    pub id: String,
    pub name: String,
    pub location: String,
    pub icon: String,
}

// Icon helpers - GTK4 IconSize only has Inherit, Normal, Large
pub const ICON_SMALL: gtk4::IconSize = gtk4::IconSize::Normal;
pub const ICON_LARGE: gtk4::IconSize = gtk4::IconSize::Large;

fn icon(name: &str, pixel_size: i32) -> Image {
    let img = Image::from_icon_name(name);
    img.set_pixel_size(pixel_size);
    img
}

// ── Status Bar ────────────────────────────────────────────────────────────

pub fn build_status_bar(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Horizontal, 12);
    root.add_css_class("qs-status-bar");

    let name_box = GtkBox::new(Orientation::Vertical, 4);
    name_box.add_css_class("qs-device-name-box");
    name_box.set_hexpand(true);
    name_box.set_halign(gtk4::Align::Start);
    name_box.set_valign(gtk4::Align::Center);

    let name_label = Label::new(Some("Laptop C0O0C"));
    name_label.add_css_class("qs-device-name");
    name_label.set_xalign(0.0);
    name_label.set_yalign(0.5);
    name_box.append(&name_label);

    // Update name from audio state
    let state_c = state.clone();
    let name_label_c = name_label;
    glib::timeout_add_seconds_local(2, move || {
        if let Some(s) = state_c.audio_state.borrow().default_sink.clone() {
            if let Some(d) = state_c.audio_state.borrow().sinks.iter().find(|d| d.name == s) {
                name_label_c.set_text(&d.description);
            }
        }
        glib::ControlFlow::Continue
    });

    // Wi-Fi
    let wifi_box = GtkBox::new(Orientation::Horizontal, 8);
    wifi_box.add_css_class("qs-wifi-box");
    wifi_box.set_valign(gtk4::Align::Center);
    wifi_box.append(&icon("\u{f542}", 16)); // signal strong
    wifi_box.append(&Label::new(Some("Laptop")));
    root.append(&name_box);
    root.append(&wifi_box);

    // Battery
    let batt_box = GtkBox::new(Orientation::Horizontal, 6);
    batt_box.add_css_class("qs-battery-box");
    batt_box.set_valign(gtk4::Align::Center);
    batt_box.append(&icon("\u{f297}", 16)); // battery icon
    let batt_lbl = Label::new(Some("42%"));
    batt_lbl.add_css_class("qs-battery");
    batt_box.append(&batt_lbl);
    root.append(&batt_box);

    root
}

// ── Header Actions ────────────────────────────────────────────────────────

pub fn build_header_actions(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Horizontal, 8);
    root.add_css_class("qs-header-actions");
    root.set_margin_top(4);
    root.set_margin_bottom(6);
    root.set_halign(gtk4::Align::Start);

    let make_btn = |text: &str, icon_name: &str| -> Button {
        let btn = Button::new();
        btn.add_css_class("qs-action-btn");
        let inner = GtkBox::new(Orientation::Horizontal, 6);
        inner.append(&icon(icon_name, 14));
        let lbl = Label::new(Some(text));
        inner.append(&lbl);
        btn.set_child(Some(&inner));
        btn
    };

    let edit_btn = make_btn("Editar", "\u{e038}");
    edit_btn.set_label("Editar");
    edit_btn.set_use_underline(true);
    let state_e = state.clone();
    let edit_lbl = edit_btn.clone();
    edit_btn.connect_clicked(move |_| {
        let new = !state_e.edit_mode.get();
        state_e.edit_mode.set(new);
        edit_lbl.set_label(if new { "Finalizar" } else { "Editar" });
    });
    root.append(&edit_btn);

    root.append(&make_btn("Apagar", "\u{e31c}"));
    root.append(&make_btn("Configuración", "\u{e8b4}"));

    root
}

// ── Quick Toggles ─────────────────────────────────────────────────────────

fn build_quick_toggle(
    icon_name: &str,
    title: &str,
    is_on: bool,
    on_click: impl Fn() + 'static,
) -> Button {
    let btn = Button::new();
    btn.add_css_class("qs-toggle-circular");
    btn.add_css_class("qs-toggle");
    if is_on {
        btn.add_css_class("active");
    }

    let inner = GtkBox::new(Orientation::Vertical, 6);
    inner.set_spacing(8);
    inner.set_valign(gtk4::Align::Center);
    inner.set_halign(gtk4::Align::Center);

    let img = icon(icon_name, 26);
    let lbl = Label::new(Some(title));
    lbl.set_halign(gtk4::Align::Center);
    lbl.set_valign(gtk4::Align::Center);

    inner.append(&img);
    inner.append(&lbl);
    btn.set_child(Some(&inner));
    btn.connect_clicked(move |_| on_click());

    btn
}

fn build_wide_toggle(
    icon_name: &str,
    title: &str,
    subtitle: &str,
    is_on: bool,
    on_click: impl Fn() + 'static,
) -> Button {
    let btn = Button::new();
    btn.add_css_class("qs-toggle-wide");
    btn.add_css_class("qs-toggle");
    if is_on {
        btn.add_css_class("active");
    }

    let img = icon(icon_name, 18);
    let title_lbl = Label::new(Some(title));
    title_lbl.add_css_class("qs-title");
    let sub_lbl = Label::new(Some(subtitle));
    sub_lbl.add_css_class("qs-subtitle");

    let text_box = GtkBox::new(Orientation::Vertical, 2);
    text_box.append(&title_lbl);
    text_box.append(&sub_lbl);

    let inner = GtkBox::new(Orientation::Horizontal, 10);
    inner.set_valign(gtk4::Align::Center);
    inner.append(&img);
    inner.append(&text_box);
    btn.set_child(Some(&inner));
    btn.connect_clicked(move |_| on_click());
    btn
}

fn build_small_toggle(
    icon_name: &str,
    label: &str,
    is_on: bool,
    on_click: impl Fn() + 'static,
) -> Button {
    let btn = Button::new();
    btn.add_css_class("qs-toggle-small");
    btn.add_css_class("qs-toggle");
    if is_on {
        btn.add_css_class("active");
    }
    let inner = GtkBox::new(Orientation::Vertical, 4);
    inner.set_spacing(4);
    inner.set_valign(gtk4::Align::Center);
    inner.append(&icon(icon_name, 14));
    inner.append(&Label::new(Some(label)));
    btn.set_child(Some(&inner));
    btn.connect_clicked(move |_| on_click());
    btn
}

// ── Control Grid ──────────────────────────────────────────────────────────

pub fn build_control_grid(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-control-grid");

    let title = Label::new(Some("Controles Rápidos"));
    title.add_css_class("qs-section-title");
    title.set_halign(gtk4::Align::Start);
    title.set_xalign(0.0);
    root.append(&title);

    let grid = Grid::new();
    grid.add_css_class("qs-grid");
    grid.set_column_spacing(10);
    grid.set_row_spacing(10);
    root.append(&grid);

    // Row 0 (col 0-3): Circular toggles: WiFi, Cellular, Bluetooth, Dark Mode
    let wifi = build_quick_toggle("\u{e1b6}", "Wi-Fi", true, move || {});
    grid.attach(&wifi, 0, 0, 1, 1);

    let cellular = build_quick_toggle("\u{f4fc}", "Datos", true, || {});
    grid.attach(&cellular, 1, 0, 1, 1);

    let bt = build_quick_toggle("\u{e1f6}", "Bluetooth", true, || {});
    grid.attach(&bt, 2, 0, 1, 1);

    let dark = build_quick_toggle("\u{e3a9}", "Modo Oscuro", true, || {});
    grid.attach(&dark, 3, 0, 1, 1);

    // Row 1 (col 0-1): Small toggles: Notifications, Display
    let notif = build_small_toggle("\u{e7f7}", "Notif", true, || {});
    grid.attach(&notif, 0, 1, 1, 1);
    let display = build_small_toggle("\u{e8f6}", "Display", false, || {});
    grid.attach(&display, 1, 1, 1, 1);

    // Row 1 (col 2-3): Small toggles: Camera, VPN
    let camera = build_small_toggle("\u{e3b2}", "Cámara", true, || {});
    grid.attach(&camera, 2, 1, 1, 1);
    let vpn = build_small_toggle("\u{e62b}", "VPN", false, || {});
    grid.attach(&vpn, 3, 1, 1, 1);

    // Row 2-4: Widget tiles (weather, time, etc.)
    let weather = make_widget_tile("\u{f296}", "Clima", "Soleado");
    grid.attach(&weather, 0, 2, 2, 2);

    let time = make_widget_tile("\u{e7eb}", "Hora", "14:30");
    grid.attach(&time, 2, 2, 2, 2);

    // Row 2 col 0-1 (already used by weather), maybe add another widget tile
    let temp = make_widget_tile("\u{e3c7}", "Temp", "23°");
    grid.attach(&temp, 0, 2, 2, 1);

    // Row 2 (col 4): Add slot
    let add_slot = make_add_slot();
    grid.attach(&add_slot, 4, 0, 1, 3);

    root
}

fn make_widget_tile(icon_name: &str, title: &str, value: &str) -> Button {
    let btn = Button::new();
    btn.add_css_class("qs-card");
    let inner = GtkBox::new(Orientation::Vertical, 6);
    inner.set_margin_start(8);
    inner.set_margin_end(8);
    inner.set_margin_top(6);
    inner.set_margin_bottom(6);
    inner.append(&icon(icon_name, 24));
    inner.append(&Label::new(Some(title)));
    inner.append(&Label::new(Some(value)));
    btn.set_child(Some(&inner));
    btn
}

fn make_add_slot() -> Button {
    let btn = Button::new();
    btn.add_css_class("add-slot");
    let inner = GtkBox::new(Orientation::Vertical, 8);
    inner.set_valign(gtk4::Align::Center);
    inner.append(&Label::new(Some("\u{e702}"))); // add icon
    inner.append(&Label::new(Some("Agregar")));
    btn.set_child(Some(&inner));
    btn
}

// ── Vertical Sliders ─────────────────────────────────────────────────────

fn make_vertical_slider(
    root: &GtkBox,
    label: &str,
    value_lbl: &Label,
    initial: f64,
    max: f64,
    on_change: impl Fn(f64) + 'static,
) {
    let scale = Scale::new(
        Orientation::Vertical,
        Some(&Adjustment::new(initial, 0.0, max, 1.0, 5.0, 0.0)),
    );
    scale.add_css_class("qs-slider");
    scale.set_draw_value(false);
    scale.set_halign(gtk4::Align::Center);
    scale.set_hexpand(false);
    scale.set_hexpand(true);
    scale.set_vexpand(true);
    scale.set_size_request(28, 200);
    scale.set_value(initial);
    let value_lbl_c = value_lbl.clone();
    scale.connect_value_changed(move |s| {
        let v = s.value();
        value_lbl_c.set_text(&format!("{:.0}%", v));
        on_change(v);
    });
    root.append(&scale);
}

pub fn build_brightness_slider(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-slider-box");

    let label_row = GtkBox::new(Orientation::Horizontal, 0);
    label_row.add_css_class("qs-slider-label-row");
    let lbl = Label::new(Some("Brillo"));
    lbl.add_css_class("qs-slider-label");
    label_row.append(&lbl);
    let value_lbl = Label::new(Some("75%"));
    value_lbl.add_css_class("qs-slider-value");
    value_lbl.set_halign(gtk4::Align::End);
    label_row.append(&value_lbl);
    root.append(&label_row);

    // Icon
    let icon_box = GtkBox::new(Orientation::Vertical, 8);
    icon_box.set_halign(gtk4::Align::End);
    icon_box.set_valign(gtk4::Align::Center);
    icon_box.append(&icon("\u{f5dc}", 16));

    // Inner container
    let inner = GtkBox::new(Orientation::Horizontal, 12);
    inner.set_valign(gtk4::Align::Center);
    inner.set_halign(gtk4::Align::Center);
    inner.set_hexpand(true);
    inner.set_vexpand(true);

    // Add slider after inner is built
    let state_c = state.clone();
    let vlbl = value_lbl.clone();
    make_vertical_slider(&inner, "Brillo", &vlbl, 50.0, 100.0, move |v| {
        state_c.brightness.set(v as f32);
    });

    inner.append(&icon_box);
    root.append(&inner);
    root
}

pub fn build_volume_slider(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-slider-box");
    root.set_margin_top(4);

    let label_row = GtkBox::new(Orientation::Horizontal, 0);
    label_row.add_css_class("qs-slider-label-row");
    let lbl = Label::new(Some("Volumen"));
    lbl.add_css_class("qs-slider-label");
    label_row.append(&lbl);
    let value_lbl = Label::new(Some("50%"));
    value_lbl.add_css_class("qs-slider-value");
    value_lbl.set_halign(gtk4::Align::End);
    label_row.append(&value_lbl);
    root.append(&label_row);

    let icon_box = GtkBox::new(Orientation::Vertical, 8);
    icon_box.set_halign(gtk4::Align::End);
    icon_box.set_valign(gtk4::Align::Center);
    icon_box.append(&icon("\u{e1b4}", 16));

    let inner = GtkBox::new(Orientation::Horizontal, 12);
    inner.set_valign(gtk4::Align::Center);
    inner.set_halign(gtk4::Align::Center);
    inner.set_hexpand(true);
    inner.set_vexpand(true);

    let state_c = state.clone();
    let vlbl = value_lbl.clone();
    make_vertical_slider(&inner, "Volumen", &vlbl, 50.0, 150.0, move |v| {
        state_c.volume.set(v as f32);
        state_c.set_volume(v as f32);
    });

    inner.append(&icon_box);
    root.append(&inner);
    root
}

// ── Smart Device Card ────────────────────────────────────────────────────

pub fn build_device_status_card(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-device-card-container");

    let title = Label::new(Some("Dispositivos Inteligentes"));
    title.add_css_class("qs-section-title");
    title.set_halign(gtk4::Align::Start);
    title.set_xalign(0.0);
    root.append(&title);

    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("qs-device");

    for device in state.smart_devices.borrow().iter() {
        let item = make_device_item(device, state.clone());
        card.append(&item);
    }

    root.append(&card);
    root
}

fn make_device_item(device: &SmartDevice, state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-device-item");
    root.set_margin_start(10);
    root.set_margin_end(10);
    root.set_margin_top(10);

    let head = GtkBox::new(Orientation::Horizontal, 12);

    // Icon
    let icon_box = GtkBox::new(Orientation::Vertical, 4);
    icon_box.set_margin_start(6);
    icon_box.append(&icon(&device.icon, 32));

    // Text info
    let name_box = GtkBox::new(Orientation::Vertical, 2);
    name_box.set_hexpand(true);
    let name = Label::new(Some(&device.name));
    name.add_css_class("qs-device-name");
    let loc = Label::new(Some(&device.location));
    loc.add_css_class("qs-device-desc");
    name_box.append(&name);
    name_box.append(&loc);

    // Actions
    let actions = GtkBox::new(Orientation::Horizontal, 4);
    actions.add_css_class("qs-device-actions");

    let ctrl = Button::new();
    ctrl.add_css_class("qs-device-btn");
    ctrl.set_tooltip_text(Some("Control"));
    ctrl.set_child(Some(&icon("\u{e2a7}", 16)));
    ctrl.connect_clicked(move |_| {
        tracing::info!("Control");
    });
    actions.append(&ctrl);

    let upd = Button::new();
    upd.add_css_class("qs-device-btn");
    upd.set_tooltip_text(Some("Actualizar"));
    upd.set_child(Some(&icon("\u{e5d5}", 16)));
    upd.connect_clicked(move |_| {
        tracing::info!("Actualizar");
    });
    actions.append(&upd);

    let off = Button::new();
    off.add_css_class("qs-device-btn");
    off.set_tooltip_text(Some("Apagar"));
    off.set_child(Some(&icon("\u{e1b1}", 16)));
    off.connect_clicked(move |_| {
        tracing::info!("Apagar");
    });
    actions.append(&off);

    head.append(&icon_box);
    head.append(&name_box);
    head.append(&actions);
    root.append(&head);

    root
}

// ── Edit Mode Bar ────────────────────────────────────────────────────────

pub fn build_edit_mode_bar(state: Rc<QuickSettingsState>) -> GtkBox {
    let root = GtkBox::new(Orientation::Vertical, 8);
    root.add_css_class("qs-edit-bar");
    root.set_margin_top(8);

    // Description text
    let desc = Label::new(Some("Modo de edición - arrastra controles, usa Eliminar para retirarlos."));
    desc.add_css_class("qs-edit-desc");
    desc.set_halign(gtk4::Align::Start);
    desc.set_xalign(0.0);
    root.append(&desc);

    // Add control
    let add_btn = Button::new();
    add_btn.add_css_class("qs-edit-action");
    let inner_add = GtkBox::new(Orientation::Horizontal, 6);
    inner_add.append(&icon("\u{e702}", 16));
    inner_add.append(&Label::new(Some("Agregar Control")));
    add_btn.set_child(Some(&inner_add));
    add_btn.connect_clicked(move |_| {
        tracing::info!("Agregar control");
    });
    root.append(&add_btn);

    // Discard changes
    let discard_btn = Button::new();
    discard_btn.add_css_class("qs-edit-action");
    discard_btn.set_label("Descartar Cambios");
    discard_btn.connect_clicked(move |_| {
        tracing::info!("Descartar");
    });
    root.append(&discard_btn);

    root
}
