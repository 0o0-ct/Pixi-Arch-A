//! Widgets reutilizables del tema glass.
//!
//! Cada widget es una función helper que crea un widget GTK4 con las clases CSS
//! correctas del tema. Se reutilizan en glass-bt y glass-audio.

use gtk4::prelude::*;
use gtk4::{Box, Button, Label, Orientation};

use crate::tokens::css_class;
use crate::tokens::icon_size;

/// Crea un panel glass (contenedor principal con efecto frosted glass).
pub fn glass_panel(orientation: Orientation, spacing: i32) -> Box {
    let panel = Box::new(orientation, spacing);
    panel.add_css_class(css_class::GLASS_PANEL);
    panel
}

/// Crea una tarjeta de dispositivo.
pub fn device_card() -> Box {
    let card = Box::new(Orientation::Horizontal, 0);
    card.add_css_class(css_class::DEVICE_CARD);
    card
}

/// Crea un squircle de icono (44x44 con radio 14).
pub fn icon_squircle(icon_name: &str, variant: &str) -> Box {
    let squircle = Box::new(Orientation::Vertical, 0);
    squircle.add_css_class(css_class::DEVICE_SQUIRCLE);
    if !variant.is_empty() {
        squircle.add_css_class(variant);
    }
    squircle.set_size_request(icon_size::SQUIRCLE, icon_size::SQUIRCLE);
    squircle.set_halign(gtk4::Align::Center);
    squircle.set_valign(gtk4::Align::Center);

    let icon = Label::new(Some(icon_name));
    icon.set_halign(gtk4::Align::Center);
    icon.set_valign(gtk4::Align::Center);
    squircle.append(&icon);

    squircle
}

/// Crea un botón de acción en píldora.
pub fn action_button(label: &str, variant: &str) -> Button {
    let btn = Button::with_label(label);
    btn.add_css_class(css_class::BTN_ACTION);
    if !variant.is_empty() {
        btn.add_css_class(variant);
    }
    btn
}

/// Crea un botón de icono tonal (silenciar, candado, etc.).
pub fn icon_button(icon: &str, tooltip: &str) -> Button {
    let btn = Button::new();
    btn.set_child(Some(&Label::new(Some(icon))));
    btn.set_tooltip_text(Some(tooltip));
    btn.set_size_request(32, 32);
    btn
}

/// Crea un label de sección (uppercase, dim).
pub fn section_label(text: &str) -> Label {
    let label = Label::new(Some(text));
    label.add_css_class(css_class::SECTION_LABEL);
    label.set_halign(gtk4::Align::Start);
    label
}

/// Crea un label de título de panel.
pub fn panel_title(text: &str) -> Label {
    let label = Label::new(Some(text));
    label.add_css_class(css_class::PANEL_TITLE);
    label
}

/// Crea un label de subtítulo.
pub fn panel_subtitle(text: &str) -> Label {
    let label = Label::new(Some(text));
    label.add_css_class(css_class::PANEL_SUBTITLE);
    label
}

/// Crea un badge (batería, estado, etc.).
pub fn badge(text: &str) -> Label {
    let label = Label::new(Some(text));
    label.add_css_class(css_class::BADGE_BATTERY);
    label
}

/// Crea un entry de búsqueda con estilo glass.
pub fn search_entry(placeholder: &str) -> gtk4::Entry {
    let entry = gtk4::Entry::new();
    entry.add_css_class(css_class::GLASS_SEARCH);
    entry.set_placeholder_text(Some(placeholder));
    entry
}

/// Crea un switch iOS-style.
pub fn ios_switch() -> gtk4::Switch {
    let switch = gtk4::Switch::new();
    switch.add_css_class(css_class::IOS_SWITCH);
    switch
}

/// Crea un botón de cerrar ventana.
pub fn close_button() -> Button {
    let btn = Button::new();
    btn.add_css_class(css_class::BTN_CLOSE_WINDOW);
    btn.set_tooltip_text(Some("Cerrar"));
    btn
}

/// Crea un botón de escanear/refrescar.
pub fn scan_button() -> Button {
    let btn = Button::new();
    btn.add_css_class(css_class::BTN_SCAN);
    btn.set_tooltip_text(Some("Escanear"));
    btn
}