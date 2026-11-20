use gtk4::prelude::*;
use gtk4::{glib, Box, Button, Image, Label, Orientation, Switch};
use crate::events::NetCommand;
use crate::ui::icons::{create_texture, create_icon_image, svgs};

pub struct Header {
    pub container: Box,
    pub subtitle_label: Label,
    pub scan_button: Button,
    pub power_switch: Switch,
    pub close_button: Button,
    pub icon_image: Image,
    pub icon_tile: Box,
}

impl Header {
    pub fn new(cmd_tx: async_channel::Sender<NetCommand>) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        container.set_hexpand(true);
        container.set_valign(gtk4::Align::Center);

        // Icono Wi-Fi dentro de un squircle fijo (44x44) con color dinámico
        let icon_tile = Box::new(Orientation::Vertical, 0);
        icon_tile.add_css_class("device-squircle");
        icon_tile.add_css_class("accent");
        icon_tile.set_valign(gtk4::Align::Center);
        icon_tile.set_halign(gtk4::Align::Center);
        icon_tile.set_size_request(44, 44);
        icon_tile.set_hexpand(false);
        icon_tile.set_vexpand(false);

        let icon_image = create_icon_image(svgs::WIFI, "#ffffff", 22);
        icon_image.set_halign(gtk4::Align::Center);
        icon_image.set_valign(gtk4::Align::Center);
        icon_image.set_vexpand(true);
        icon_image.set_hexpand(false);
        icon_tile.append(&icon_image);

        // Textos (Título y subtítulo)
        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let title_label = Label::new(Some("Red"));
        title_label.set_halign(gtk4::Align::Start);
        title_label.add_css_class("panel-title");
        text_box.append(&title_label);

        let subtitle_label = Label::new(Some("Conectando a NetworkManager…"));
        subtitle_label.set_halign(gtk4::Align::Start);
        subtitle_label.add_css_class("panel-subtitle");
        text_box.append(&subtitle_label);

        // Área de título arrastrable con cursor interactivo
        let drag_handle = gtk4::WindowHandle::new();
        drag_handle.set_cursor_from_name(Some("grab"));
        let title_box = Box::new(Orientation::Horizontal, 10);
        title_box.set_hexpand(true);
        title_box.append(&icon_tile);
        title_box.append(&text_box);
        drag_handle.set_child(Some(&title_box));
        drag_handle.set_hexpand(true);
        container.append(&drag_handle);

        // Botón de escaneo / refresh con icono Lucide refresh-cw
        let scan_button = Button::new();
        scan_button.add_css_class("btn-scan");
        scan_button.set_tooltip_text(Some("Buscar redes disponibles"));
        scan_button.set_valign(gtk4::Align::Center);

        let scan_img = create_icon_image(svgs::REFRESH_CW, "#ffffff", 16);
        scan_button.set_child(Some(&scan_img));

        let tx_scan = cmd_tx.clone();
        scan_button.connect_clicked(move |_| {
            let _ = tx_scan.send_blocking(NetCommand::StartScan);
        });
        container.append(&scan_button);

        // Switch iOS (Wi-Fi encendido/apagado)
        let power_switch = Switch::new();
        power_switch.add_css_class("ios-switch");
        power_switch.set_valign(gtk4::Align::Center);

        let tx_power = cmd_tx;
        power_switch.connect_state_set(move |switch, state| {
            let _ = tx_power.send_blocking(NetCommand::SetWifi(state));
            switch.set_state(state);
            glib::Propagation::Proceed
        });
        container.append(&power_switch);

        // Botón de cerrar ventana con icono Lucide x
        let close_button = Button::new();
        close_button.add_css_class("btn-close-window");
        close_button.set_tooltip_text(Some("Cerrar ventana (Esc)"));
        close_button.set_valign(gtk4::Align::Center);

        let close_img = create_icon_image(svgs::X, "rgba(255, 255, 255, 0.75)", 16);
        close_button.set_child(Some(&close_img));
        container.append(&close_button);

        Self {
            container,
            subtitle_label,
            scan_button,
            power_switch,
            close_button,
            icon_image,
            icon_tile,
        }
    }

    pub fn set_wifi_enabled(&self, enabled: bool) {
        self.power_switch.set_active(enabled);
        self.power_switch.set_state(enabled);
        if !enabled {
            self.scan_button.set_sensitive(false);
            self.scan_button.remove_css_class("scanning");
            self.icon_tile.remove_css_class("accent");
            self.icon_tile.add_css_class("disabled");
            if let Some(tex) = create_texture(svgs::WIFI_OFF, "rgba(255, 255, 255, 0.40)", 22) {
                self.icon_image.set_paintable(Some(&tex));
            }
        } else {
            self.scan_button.set_sensitive(true);
            self.icon_tile.remove_css_class("disabled");
            self.icon_tile.add_css_class("accent");
            if let Some(tex) = create_texture(svgs::WIFI, "#ffffff", 22) {
                self.icon_image.set_paintable(Some(&tex));
            }
        }
    }

    pub fn set_scanning(&self, scanning: bool) {
        if scanning {
            self.scan_button.add_css_class("scanning");
            self.scan_button.set_tooltip_text(Some("Escaneando redes…"));
        } else {
            self.scan_button.remove_css_class("scanning");
            self.scan_button.set_tooltip_text(Some("Buscar redes disponibles"));
        }
    }

    pub fn update_subtitle(&self, text: &str) {
        self.subtitle_label.set_text(text);
    }
}
