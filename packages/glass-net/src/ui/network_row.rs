use gtk4::prelude::*;
use gtk4::{Box, Button, Label, Orientation};
use crate::events::{ApInfo, EthernetInfo, NetCommand, VpnInfo};
use crate::ui::icons::{create_icon_image, svgs};

pub struct NetworkRow {
    pub container: Box,
}

impl NetworkRow {
    /// Fila de un punto de acceso Wi-Fi (conectado / guardada / disponible)
    pub fn ap(
        info: &ApInfo,
        connected: bool,
        known: bool,
        cmd_tx: async_channel::Sender<NetCommand>,
        device_path: String,
    ) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        container.add_css_class("device-card");
        if connected {
            container.add_css_class("connected");
        }
        container.set_hexpand(true);

        // Squircle Tile 44x44: accent si está conectada, neutra en otro caso
        let icon_box = Box::new(Orientation::Vertical, 0);
        icon_box.add_css_class("device-squircle");
        if connected {
            icon_box.add_css_class("accent");
            icon_box.add_css_class("connected");
        }
        icon_box.set_valign(gtk4::Align::Center);
        icon_box.set_halign(gtk4::Align::Center);
        icon_box.set_size_request(44, 44);
        icon_box.set_hexpand(false);
        icon_box.set_vexpand(false);

        let icon = create_icon_image(svgs::WIFI, "#ffffff", 22);
        icon.set_halign(gtk4::Align::Center);
        icon.set_valign(gtk4::Align::Center);
        icon.set_vexpand(true);
        icon.set_hexpand(false);
        icon_box.append(&icon);
        container.append(&icon_box);

        // Textos (SSID y estado)
        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let display_name = if info.ssid.is_empty() { "Red oculta" } else { &info.ssid };
        let name_label = Label::new(Some(display_name));
        name_label.set_halign(gtk4::Align::Start);
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.add_css_class("device-name");
        text_box.append(&name_label);

        // Fila de estado (Punto de color + Texto + candado + barras de señal)
        let status_box = Box::new(Orientation::Horizontal, 5);
        status_box.set_halign(gtk4::Align::Start);
        status_box.set_valign(gtk4::Align::Center);

        let status_dot = Box::new(Orientation::Horizontal, 0);
        if connected {
            status_dot.add_css_class("status-dot-green");
        } else {
            status_dot.add_css_class("status-dot-dim");
        }
        status_dot.set_valign(gtk4::Align::Center);
        status_box.append(&status_dot);

        let status_str = if connected {
            "Conectado"
        } else if known {
            "Guardada"
        } else {
            info.security_label.as_str()
        };
        let status_label = Label::new(Some(status_str));
        status_label.add_css_class("device-sub");
        if connected {
            status_label.add_css_class("connected");
        }
        status_box.append(&status_label);

        // Candado si la red está protegida
        if info.secure {
            let lock = create_icon_image(svgs::LOCK, "rgba(255, 255, 255, 0.65)", 11);
            lock.set_valign(gtk4::Align::Center);
            lock.set_margin_start(2);
            status_box.append(&lock);
        }

        // Barras de intensidad de señal 0-100
        let signal_widget = Self::create_signal_bars(info.strength);
        status_box.append(&signal_widget);

        text_box.append(&status_box);
        container.append(&text_box);

        // Botones de acción (Píldoras)
        let actions_box = Box::new(Orientation::Horizontal, 6);
        actions_box.set_valign(gtk4::Align::Center);

        let ap_path = info.path.clone();

        if connected {
            let action_btn = Button::new();
            action_btn.add_css_class("btn-action");
            action_btn.add_css_class("btn-disconnect");
            action_btn.set_label("Desconectar");
            let tx = cmd_tx.clone();
            let dev = device_path.clone();
            let btn_clone = action_btn.clone();
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Desconectando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::DisconnectDevice(dev.clone()));
            });
            actions_box.append(&action_btn);

            if known {
                let forget_btn = Self::forget_button(&cmd_tx, &ap_path);
                actions_box.append(&forget_btn);
            }
        } else {
            let action_btn = Button::new();
            action_btn.add_css_class("btn-action");
            action_btn.add_css_class("btn-connect");
            action_btn.set_label("Conectar");
            let tx = cmd_tx.clone();
            let p = ap_path.clone();
            let btn_clone = action_btn.clone();
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Conectando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::ConnectAp(p.clone()));
            });
            actions_box.append(&action_btn);

            if known {
                let forget_btn = Self::forget_button(&cmd_tx, &ap_path);
                actions_box.append(&forget_btn);
            }
        }

        container.append(&actions_box);

        Self { container }
    }

    /// Fila de red cableada (Ethernet)
    pub fn ethernet(info: &EthernetInfo, cmd_tx: async_channel::Sender<NetCommand>) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        let connected = info.state == DEV_STATE_ACTIVATED;
        if connected {
            container.add_css_class("connected");
        }
        container.add_css_class("device-card");
        container.set_hexpand(true);

        let icon_box = Box::new(Orientation::Vertical, 0);
        icon_box.add_css_class("device-squircle");
        icon_box.add_css_class("ethernet");
        if connected {
            icon_box.add_css_class("connected");
        }
        icon_box.set_valign(gtk4::Align::Center);
        icon_box.set_halign(gtk4::Align::Center);
        icon_box.set_size_request(44, 44);
        icon_box.set_hexpand(false);
        icon_box.set_vexpand(false);

        let icon = create_icon_image(svgs::ETHERNET, "#ffffff", 22);
        icon.set_halign(gtk4::Align::Center);
        icon.set_valign(gtk4::Align::Center);
        icon.set_vexpand(true);
        icon.set_hexpand(false);
        icon_box.append(&icon);
        container.append(&icon_box);

        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let name_label = Label::new(Some("Red cableada"));
        name_label.set_halign(gtk4::Align::Start);
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.add_css_class("device-name");
        text_box.append(&name_label);

        let status_box = Box::new(Orientation::Horizontal, 5);
        status_box.set_halign(gtk4::Align::Start);
        status_box.set_valign(gtk4::Align::Center);

        let status_dot = Box::new(Orientation::Horizontal, 0);
        if connected {
            status_dot.add_css_class("status-dot-green");
        } else {
            status_dot.add_css_class("status-dot-dim");
        }
        status_dot.set_valign(gtk4::Align::Center);
        status_box.append(&status_dot);

        let status_str = match info.state {
            DEV_STATE_ACTIVATED => match &info.ip {
                Some(ip) => format!("Conectado • {ip}"),
                None => "Conectado".into(),
            },
            20 => "Cable no conectado".into(),
            40..=90 => "Conectando…".into(),
            _ => "Desconectada".into(),
        };
        let status_label = Label::new(Some(&status_str));
        status_label.add_css_class("device-sub");
        if connected {
            status_label.add_css_class("connected");
        }
        status_box.append(&status_label);

        text_box.append(&status_box);
        container.append(&text_box);

        let actions_box = Box::new(Orientation::Horizontal, 6);
        actions_box.set_valign(gtk4::Align::Center);

        let action_btn = Button::new();
        action_btn.add_css_class("btn-action");
        let tx = cmd_tx.clone();
        let dev = info.device_path.clone();
        let btn_clone = action_btn.clone();
        if connected {
            action_btn.add_css_class("btn-disconnect");
            action_btn.set_label("Desconectar");
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Desconectando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::DisconnectDevice(dev.clone()));
            });
        } else if info.state == 30 {
            action_btn.add_css_class("btn-connect");
            action_btn.set_label("Conectar");
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Conectando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::ConnectEthernet(dev.clone()));
            });
        } else {
            action_btn.set_sensitive(false);
            action_btn.set_label("—");
        }
        actions_box.append(&action_btn);

        container.append(&actions_box);

        Self { container }
    }

    /// Fila de conexión VPN
    pub fn vpn(info: &VpnInfo, cmd_tx: async_channel::Sender<NetCommand>) -> Self {
        let container = Box::new(Orientation::Horizontal, 10);
        if info.active {
            container.add_css_class("connected");
        }
        container.add_css_class("device-card");
        container.set_hexpand(true);

        let icon_box = Box::new(Orientation::Vertical, 0);
        icon_box.add_css_class("device-squircle");
        icon_box.add_css_class("vpn");
        if info.active {
            icon_box.add_css_class("connected");
        }
        icon_box.set_valign(gtk4::Align::Center);
        icon_box.set_halign(gtk4::Align::Center);
        icon_box.set_size_request(44, 44);
        icon_box.set_hexpand(false);
        icon_box.set_vexpand(false);

        let icon = create_icon_image(svgs::SERVER, "#ffffff", 22);
        icon.set_halign(gtk4::Align::Center);
        icon.set_valign(gtk4::Align::Center);
        icon.set_vexpand(true);
        icon.set_hexpand(false);
        icon_box.append(&icon);
        container.append(&icon_box);

        let text_box = Box::new(Orientation::Vertical, 2);
        text_box.set_hexpand(true);
        text_box.set_valign(gtk4::Align::Center);

        let name_label = Label::new(Some(&info.name));
        name_label.set_halign(gtk4::Align::Start);
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.add_css_class("device-name");
        text_box.append(&name_label);

        let status_box = Box::new(Orientation::Horizontal, 5);
        status_box.set_halign(gtk4::Align::Start);
        status_box.set_valign(gtk4::Align::Center);

        let status_dot = Box::new(Orientation::Horizontal, 0);
        if info.active {
            status_dot.add_css_class("status-dot-green");
        } else {
            status_dot.add_css_class("status-dot-dim");
        }
        status_dot.set_valign(gtk4::Align::Center);
        status_box.append(&status_dot);

        let status_label = Label::new(Some(if info.active { "Activa" } else { "Disponible" }));
        status_label.add_css_class("device-sub");
        if info.active {
            status_label.add_css_class("connected");
        }
        status_box.append(&status_label);

        text_box.append(&status_box);
        container.append(&text_box);

        let actions_box = Box::new(Orientation::Horizontal, 6);
        actions_box.set_valign(gtk4::Align::Center);

        let action_btn = Button::new();
        action_btn.add_css_class("btn-action");
        let tx = cmd_tx.clone();
        let btn_clone = action_btn.clone();
        if info.active {
            action_btn.add_css_class("btn-disconnect");
            action_btn.set_label("Desactivar");
            let active_path = info.active_path.clone();
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Desactivando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::DisconnectVpn(active_path.clone()));
            });
        } else {
            action_btn.add_css_class("btn-connect");
            action_btn.set_label("Conectar");
            let uuid = info.uuid.clone();
            action_btn.connect_clicked(move |_| {
                btn_clone.set_label("Conectando…");
                btn_clone.set_sensitive(false);
                let _ = tx.send_blocking(NetCommand::ConnectVpn(uuid.clone()));
            });
        }
        actions_box.append(&action_btn);

        container.append(&actions_box);

        Self { container }
    }

    /// Botón de olvidar red (Papelera Lucide)
    fn forget_button(cmd_tx: &async_channel::Sender<NetCommand>, ap_path: &str) -> Button {
        let forget_btn = Button::new();
        forget_btn.add_css_class("btn-forget");
        forget_btn.set_tooltip_text(Some("Olvidar esta red"));
        let trash_img = create_icon_image(svgs::TRASH, "rgba(255, 255, 255, 0.65)", 15);
        forget_btn.set_child(Some(&trash_img));

        let tx = cmd_tx.clone();
        let p = ap_path.to_string();
        let forget_clone = forget_btn.clone();
        forget_btn.connect_clicked(move |_| {
            forget_clone.set_sensitive(false);
            let _ = tx.send_blocking(NetCommand::Forget(p.clone()));
        });
        forget_btn
    }

    /// Crea un indicador de 4 barras estilo celular/One UI basado en Strength (0-100)
    fn create_signal_bars(strength: u8) -> Box {
        let signal_box = Box::new(Orientation::Horizontal, 1);
        signal_box.add_css_class("signal-box");
        signal_box.set_valign(gtk4::Align::End);
        signal_box.set_tooltip_text(Some(&format!("Señal {strength}%")));

        let active_bars = if strength >= 80 {
            4
        } else if strength >= 55 {
            3
        } else if strength >= 25 {
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

const DEV_STATE_ACTIVATED: u32 = 100;
