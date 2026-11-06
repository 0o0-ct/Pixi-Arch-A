use gtk4::prelude::*;
use gtk4::{glib, Box, Button, Image, Label, Orientation, Switch};
use crate::events::BtCommand;

pub struct Header {
    pub container: Box,
    pub title_label: Label,
    pub subtitle_label: Label,
    pub scan_button: Button,
    pub power_switch: Switch,
    pub close_button: Button,
}

impl Header {
    pub fn new(cmd_tx: async_channel::Sender<BtCommand>) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        container.set_hexpand(true);
        container.set_valign(gtk4::Align::Center);

        // Icono Bluetooth dentro de un squircle sutil
        let icon_tile = Box::new(Orientation::Vertical, 0);
        icon_tile.add_css_class("device-squircle");
        icon_tile.add_css_class("mouse"); // usa gradiente cian
        icon_tile.set_valign(gtk4::Align::Center);

        let icon = Image::from_icon_name("bluetooth-active-symbolic");
        icon.set_pixel_size(22);
        icon_tile.append(&icon);

        // Textos (Título y subtítulo)
        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let title_label = Label::new(Some("Bluetooth"));
        title_label.set_halign(gtk4::Align::Start);
        title_label.add_css_class("panel-title");
        text_box.append(&title_label);

        let subtitle_label = Label::new(Some("Buscando adaptador..."));
        subtitle_label.set_halign(gtk4::Align::Start);
        subtitle_label.add_css_class("panel-subtitle");
        text_box.append(&subtitle_label);

        // Área de título arrastrable (WindowHandle envuelve únicamente icono y texto para no bloquear clics)
        let drag_handle = gtk4::WindowHandle::new();
        let title_box = Box::new(Orientation::Horizontal, 10);
        title_box.set_hexpand(true);
        title_box.append(&icon_tile);
        title_box.append(&text_box);
        drag_handle.set_child(Some(&title_box));
        drag_handle.set_hexpand(true);
        container.append(&drag_handle);

        // Botón de escaneo / refresh
        let scan_button = Button::from_icon_name("view-refresh-symbolic");
        scan_button.add_css_class("btn-scan");
        scan_button.set_tooltip_text(Some("Buscar dispositivos cercanos"));
        scan_button.set_valign(gtk4::Align::Center);

        let tx_scan = cmd_tx.clone();
        scan_button.connect_clicked(move |_| {
            let _ = tx_scan.send_blocking(BtCommand::ToggleScan);
        });
        container.append(&scan_button);

        // Switch iOS
        let power_switch = Switch::new();
        power_switch.add_css_class("ios-switch");
        power_switch.set_valign(gtk4::Align::Center);

        let tx_power = cmd_tx;
        power_switch.connect_state_set(move |switch, state| {
            let _ = tx_power.send_blocking(BtCommand::SetPower(state));
            switch.set_state(state);
            glib::Propagation::Proceed
        });
        container.append(&power_switch);

        // Botón de cerrar ventana
        let close_button = Button::from_icon_name("window-close-symbolic");
        close_button.add_css_class("btn-close-window");
        close_button.set_tooltip_text(Some("Cerrar ventana (Esc)"));
        close_button.set_valign(gtk4::Align::Center);
        container.append(&close_button);

        Self {
            container,
            title_label,
            subtitle_label,
            scan_button,
            power_switch,
            close_button,
        }
    }

    pub fn set_powered(&self, powered: bool) {
        self.power_switch.set_active(powered);
        self.power_switch.set_state(powered);
        if !powered {
            self.subtitle_label.set_text("Bluetooth desactivado");
            self.scan_button.set_sensitive(false);
            self.scan_button.remove_css_class("scanning");
        } else {
            self.scan_button.set_sensitive(true);
        }
    }

    pub fn set_scanning(&self, scanning: bool) {
        if scanning {
            self.scan_button.add_css_class("scanning");
            self.scan_button.set_tooltip_text(Some("Detener escaneo"));
        } else {
            self.scan_button.remove_css_class("scanning");
            self.scan_button.set_tooltip_text(Some("Buscar dispositivos cercanos"));
        }
    }

    pub fn update_counts(&self, paired_count: usize, connected_count: usize, powered: bool) {
        if !powered {
            self.subtitle_label.set_text("Desactivado");
            return;
        }

        if connected_count > 0 {
            self.subtitle_label.set_text(&format!(
                "{} conectado{} • {} guardado{}",
                connected_count,
                if connected_count > 1 { "s" } else { "" },
                paired_count,
                if paired_count > 1 { "s" } else { "" }
            ));
        } else if paired_count > 0 {
            self.subtitle_label.set_text(&format!(
                "{} dispositivo{} guardado{}",
                paired_count,
                if paired_count > 1 { "s" } else { "" },
                if paired_count > 1 { "s" } else { "" }
            ));
        } else {
            self.subtitle_label.set_text("Sin dispositivos guardados");
        }
    }
}
