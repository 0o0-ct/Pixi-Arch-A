use gtk4::prelude::*;
use gtk4::{Box, Button, Label, Orientation};
use crate::events::{BtCommand, DeviceInfo, DeviceType};
use crate::ui::icons::{create_icon_image, device_type_svg, svgs};

pub struct DeviceRow {
    pub container: Box,
    pub mac: String,
}

impl DeviceRow {
    pub fn new(info: &DeviceInfo, cmd_tx: async_channel::Sender<BtCommand>) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        container.add_css_class("device-card");
        if info.connected {
            container.add_css_class("connected");
        }
        container.set_hexpand(true);

        // Squircle Tile para icono de dispositivo (44x44px) con Lucide Icons
        let icon_box = Box::new(Orientation::Vertical, 0);
        icon_box.add_css_class("device-squircle");
        match info.device_type {
            DeviceType::Mouse | DeviceType::Keyboard => icon_box.add_css_class("mouse"),
            DeviceType::Headset => icon_box.add_css_class("headset"),
            DeviceType::Speaker => icon_box.add_css_class("speaker"),
            DeviceType::Phone => icon_box.add_css_class("phone"),
            DeviceType::Watch => icon_box.add_css_class("watch"),
            DeviceType::Tv => icon_box.add_css_class("tv"),
            DeviceType::Gamepad => icon_box.add_css_class("gamepad"),
            DeviceType::Computer => icon_box.add_css_class("mouse"),
            DeviceType::Generic => icon_box.add_css_class("accent"),
        }
        if info.connected {
            icon_box.add_css_class("connected");
        }
        icon_box.set_valign(gtk4::Align::Center);

        let icon_svg = device_type_svg(info.device_type);
        let icon = create_icon_image(icon_svg, "#ffffff", 22);
        icon_box.append(&icon);
        container.append(&icon_box);

        // Textos del dispositivo (Nombre y Estado)
        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let display_name = info.alias.as_deref().unwrap_or(&info.name);
        let name_label = Label::new(Some(display_name));
        name_label.set_halign(gtk4::Align::Start);
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.add_css_class("device-name");
        text_box.append(&name_label);

        // Fila de estado (Punto de color + Texto + Batería + Señal)
        let status_box = Box::new(Orientation::Horizontal, 5);
        status_box.set_halign(gtk4::Align::Start);
        status_box.set_valign(gtk4::Align::Center);

        let status_dot = Box::new(Orientation::Horizontal, 0);
        if info.connected {
            status_dot.add_css_class("status-dot-green");
        } else {
            status_dot.add_css_class("status-dot-dim");
        }
        status_dot.set_valign(gtk4::Align::Center);
        status_box.append(&status_dot);

        let status_str = if info.connected {
            "Conectado"
        } else if info.paired {
            "Guardado"
        } else {
            info.device_type.label()
        };
        let status_label = Label::new(Some(status_str));
        status_label.add_css_class("device-sub");
        if info.connected {
            status_label.add_css_class("connected");
        }
        status_box.append(&status_label);

        // Badge de batería si BlueZ la expone (con icono Lucide battery)
        if let Some(bat) = info.battery_percentage {
            let bat_box = Box::new(Orientation::Horizontal, 3);
            bat_box.add_css_class("badge-battery");
            bat_box.set_valign(gtk4::Align::Center);

            let bat_icon = create_icon_image(svgs::BATTERY, "rgba(255, 255, 255, 0.85)", 11);
            bat_box.append(&bat_icon);

            let bat_label = Label::new(Some(&format!("{bat}%")));
            bat_box.append(&bat_label);
            status_box.append(&bat_box);
        }

        // Barras de intensidad de señal RSSI (en vez de texto crudo "-86 dBm")
        if let Some(rssi) = info.rssi {
            let signal_widget = Self::create_signal_bars(rssi);
            status_box.append(&signal_widget);
        }

        text_box.append(&status_box);
        container.append(&text_box);

        // Botones de acción (Píldoras)
        let actions_box = Box::new(Orientation::Horizontal, 6);
        actions_box.set_valign(gtk4::Align::Center);

        let mac = info.mac.clone();

        if info.paired {
            // Botón Conectar / Desconectar
            let action_btn = Button::new();
            action_btn.add_css_class("btn-action");

            if info.connected {
                action_btn.set_label("Desconectar");
                action_btn.add_css_class("btn-disconnect");
                let tx = cmd_tx.clone();
                let m = mac.clone();
                let btn_clone = action_btn.clone();
                action_btn.connect_clicked(move |_| {
                    btn_clone.set_label("Desconectando…");
                    btn_clone.set_sensitive(false);
                    let _ = tx.send_blocking(BtCommand::Disconnect(m.clone()));
                });
            } else {
                action_btn.set_label("Conectar");
                action_btn.add_css_class("btn-connect");
                let tx = cmd_tx.clone();
                let m = mac.clone();
                let btn_clone = action_btn.clone();
                action_btn.connect_clicked(move |_| {
                    btn_clone.set_label("Conectando…");
                    btn_clone.set_sensitive(false);
                    let _ = tx.send_blocking(BtCommand::Connect(m.clone()));
                });
            }
            actions_box.append(&action_btn);

            // Botón Olvidar / Eliminar (Papelera Lucide)
            let forget_btn = Button::new();
            forget_btn.add_css_class("btn-forget");
            forget_btn.set_tooltip_text(Some("Olvidar / Desvincular"));
            let trash_img = create_icon_image(svgs::TRASH, "rgba(255, 255, 255, 0.65)", 15);
            forget_btn.set_child(Some(&trash_img));

            let tx_forget = cmd_tx;
            let m_forget = mac.clone();
            let forget_clone = forget_btn.clone();
            forget_btn.connect_clicked(move |_| {
                forget_clone.set_sensitive(false);
                let _ = tx_forget.send_blocking(BtCommand::Forget(m_forget.clone()));
            });
            actions_box.append(&forget_btn);
        } else {
            // Botón Vincular
            let pair_btn = Button::with_label("Vincular");
            pair_btn.add_css_class("btn-action");
            pair_btn.add_css_class("btn-pair");
            let tx_pair = cmd_tx;
            let m_pair = mac.clone();
            let pair_clone = pair_btn.clone();
            pair_btn.connect_clicked(move |_| {
                pair_clone.set_label("Vinculando…");
                pair_clone.set_sensitive(false);
                let _ = tx_pair.send_blocking(BtCommand::Pair(m_pair.clone()));
            });
            actions_box.append(&pair_btn);
        }

        container.append(&actions_box);

        Self {
            container,
            mac,
        }
    }

    /// Crea un indicador de 4 barras estilo celular/One UI basado en RSSI
    fn create_signal_bars(rssi: i16) -> Box {
        let signal_box = Box::new(Orientation::Horizontal, 1);
        signal_box.add_css_class("signal-box");
        signal_box.set_valign(gtk4::Align::End);
        signal_box.set_tooltip_text(Some(&format!("{rssi} dBm")));

        let active_bars = if rssi >= -60 {
            4
        } else if rssi >= -70 {
            3
        } else if rssi >= -80 {
            2
        } else {
            1
        };

        let heights = [4, 7, 10, 13];
        for (i, &h) in heights.iter().enumerate() {
            let bar = Box::new(Orientation::Vertical, 0);
            bar.add_css_class("signal-bar");
            if (i + 1) <= active_bars {
                bar.add_css_class("active");
            }
            bar.set_size_request(2, h);
            bar.set_valign(gtk4::Align::End);
            signal_box.append(&bar);
        }

        signal_box
    }
}
