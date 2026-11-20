use std::collections::{HashMap, HashSet};
use gtk4::prelude::*;
use gtk4::{
    glib, Application, ApplicationWindow, Box, Entry, EventControllerKey, Label, ListBox,
    Orientation, ScrolledWindow, Spinner,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use crate::events::{ApInfo, EthernetInfo, NetCommand, NetEvent, VpnInfo, WifiDeviceInfo};
use super::header::Header;
use super::network_row::NetworkRow;
use super::password_dialog::PasswordDialog;
use super::icons::{create_texture, svgs};

pub struct NetWindow {
    pub window: ApplicationWindow,
    pub search_entry: Entry,
    header: Header,
    status_label: Label,
    current_list: ListBox,
    current_title: Label,
    current_box: Box,
    available_title: Label,
    available_list: ListBox,
    available_header: Box,
    scan_spinner: Spinner,
    empty_label: Label,
    eth_title: Label,
    eth_list: ListBox,
    vpn_title: Label,
    vpn_list: ListBox,
    cmd_tx: async_channel::Sender<NetCommand>,
    aps: HashMap<String, ApInfo>,
    known: HashSet<String>,
    wifi_enabled: bool,
    wifi_dev: WifiDeviceInfo,
    eth: EthernetInfo,
    vpns: Vec<VpnInfo>,
    scanning: bool,
    filter_query: String,
}

impl NetWindow {
    pub fn new(app: &Application, cmd_tx: async_channel::Sender<NetCommand>, use_layer_shell: bool) -> Self {
        let window = ApplicationWindow::builder()
            .application(app)
            .title("Red")
            .default_width(460)
            .default_height(640)
            .decorated(false)
            .build();

        // ── Si se solicita modo layer-shell con flag --layer ──────────────
        if use_layer_shell {
            window.init_layer_shell();
            window.set_namespace(Some("net-glass"));
            window.set_layer(Layer::Overlay);
            window.set_keyboard_mode(KeyboardMode::OnDemand);
            window.set_anchor(Edge::Top, true);
            window.set_anchor(Edge::Right, true);
            window.set_margin(Edge::Top, 42);
            window.set_margin(Edge::Right, 16);
        }

        // ── Atajo de teclado: Escape oculta la ventana (el daemon sigue vivo) ──
        let key_controller = EventControllerKey::new();
        let win_esc = window.clone();
        let tx_esc = cmd_tx.clone();
        key_controller.connect_key_pressed(move |_, keyval, _, _| {
            if keyval == gtk4::gdk::Key::Escape {
                win_esc.hide();
                let _ = tx_esc.send_blocking(NetCommand::SetVisible(false));
                glib::Propagation::Stop
            } else {
                glib::Propagation::Proceed
            }
        });
        window.add_controller(key_controller);

        // ── Layout principal Flotante Glassmorphism ───────────────────────
        let main_panel = Box::new(Orientation::Vertical, 10);
        main_panel.add_css_class("glass-panel");

        // Barra superior de cabecera
        let header = Header::new(cmd_tx.clone());

        // Botón de cerrar: oculta la ventana (el daemon sigue precargado)
        let win_close = window.clone();
        let tx_close = cmd_tx.clone();
        header.close_button.connect_clicked(move |_| {
            win_close.hide();
            let _ = tx_close.send_blocking(NetCommand::SetVisible(false));
        });

        main_panel.append(&header.container);

        // Barra de búsqueda rápida con icono Lucide Search
        let search_entry = Entry::new();
        search_entry.add_css_class("glass-search");
        search_entry.set_placeholder_text(Some("Buscar red o dirección MAC…"));
        if let Some(tex) = create_texture(svgs::SEARCH, "rgba(255, 255, 255, 0.45)", 16) {
            search_entry.set_icon_from_paintable(gtk4::EntryIconPosition::Primary, Some(&tex));
        }
        main_panel.append(&search_entry);

        // Mensaje de estado / notificación
        let status_label = Label::new(None);
        status_label.add_css_class("panel-subtitle");
        status_label.set_halign(gtk4::Align::Center);
        status_label.set_visible(false);
        main_panel.append(&status_label);

        // ── Área de desplazamiento (ScrolledWindow) ───────────────────────
        // PolicyType::External oculta 100% la barra lateral pero permite scroll con mouse/touchpad
        let scrolled = ScrolledWindow::builder()
            .hscrollbar_policy(gtk4::PolicyType::Never)
            .vscrollbar_policy(gtk4::PolicyType::External)
            .has_frame(false)
            .min_content_height(360)
            .max_content_height(500)
            .propagate_natural_height(true)
            .build();

        let list_container = Box::new(Orientation::Vertical, 4);
        list_container.set_margin_bottom(16);

        // Sección 1: Conexión actual (Wi-Fi conectada y/o Ethernet activa)
        let current_title = Label::new(Some("CONEXIÓN ACTUAL"));
        current_title.set_halign(gtk4::Align::Start);
        current_title.add_css_class("section-title");
        list_container.append(&current_title);

        let current_box = Box::new(Orientation::Vertical, 0);
        list_container.append(&current_box);

        let current_list = ListBox::new();
        current_list.set_selection_mode(gtk4::SelectionMode::None);
        current_list.add_css_class("device-list");
        current_box.append(&current_list);

        // Sección 2: Redes Wi-Fi disponibles
        let available_header = Box::new(Orientation::Horizontal, 8);
        available_header.set_valign(gtk4::Align::Center);

        let available_title = Label::new(Some("REDES DISPONIBLES"));
        available_title.set_halign(gtk4::Align::Start);
        available_title.add_css_class("section-title");
        available_header.append(&available_title);

        let scan_spinner = Spinner::new();
        scan_spinner.set_size_request(14, 14);
        scan_spinner.set_valign(gtk4::Align::Center);
        scan_spinner.set_visible(false);
        available_header.append(&scan_spinner);

        list_container.append(&available_header);

        let empty_label = Label::new(Some("Buscando redes Wi-Fi…"));
        empty_label.add_css_class("device-sub");
        empty_label.set_halign(gtk4::Align::Start);
        empty_label.set_margin_top(4);
        empty_label.set_margin_bottom(6);
        list_container.append(&empty_label);

        let available_list = ListBox::new();
        available_list.set_selection_mode(gtk4::SelectionMode::None);
        available_list.add_css_class("device-list");
        list_container.append(&available_list);

        // Sección 3: Red cableada (cuando hay interfaz y no está activa)
        let eth_title = Label::new(Some("RED CABLEADA"));
        eth_title.set_halign(gtk4::Align::Start);
        eth_title.add_css_class("section-title");
        eth_title.set_visible(false);
        list_container.append(&eth_title);

        let eth_list = ListBox::new();
        eth_list.set_selection_mode(gtk4::SelectionMode::None);
        eth_list.add_css_class("device-list");
        eth_list.set_visible(false);
        list_container.append(&eth_list);

        // Sección 4: VPN
        let vpn_title = Label::new(Some("VPN"));
        vpn_title.set_halign(gtk4::Align::Start);
        vpn_title.add_css_class("section-title");
        vpn_title.set_visible(false);
        list_container.append(&vpn_title);

        let vpn_list = ListBox::new();
        vpn_list.set_selection_mode(gtk4::SelectionMode::None);
        vpn_list.add_css_class("device-list");
        vpn_list.set_visible(false);
        list_container.append(&vpn_list);

        scrolled.set_child(Some(&list_container));
        scrolled.set_vexpand(true);
        main_panel.append(&scrolled);

        // Contenedor raíz para mantener el panel centrado con proporciones perfectas en pantalla completa
        let root_box = Box::new(Orientation::Vertical, 0);
        root_box.set_hexpand(true);
        root_box.set_vexpand(true);
        root_box.set_halign(gtk4::Align::Fill);
        root_box.set_valign(gtk4::Align::Fill);

        main_panel.set_halign(gtk4::Align::Center);
        main_panel.set_valign(gtk4::Align::Center);
        main_panel.set_hexpand(false);
        main_panel.set_vexpand(true);
        main_panel.set_size_request(460, -1);

        root_box.append(&main_panel);
        window.set_child(Some(&root_box));

        Self {
            window,
            search_entry,
            header,
            status_label,
            current_list,
            current_title,
            current_box,
            available_title,
            available_list,
            available_header,
            scan_spinner,
            empty_label,
            eth_title,
            eth_list,
            vpn_title,
            vpn_list,
            cmd_tx,
            aps: HashMap::new(),
            known: HashSet::new(),
            wifi_enabled: false,
            wifi_dev: WifiDeviceInfo {
                present: false,
                device_path: String::new(),
                interface: String::new(),
                connected_ssid: None,
                ip: None,
                activating: false,
            },
            eth: EthernetInfo {
                device_path: String::new(),
                interface: String::new(),
                state: 0,
                ip: None,
            },
            vpns: Vec::new(),
            scanning: false,
            filter_query: String::new(),
        }
    }

    pub fn set_filter(&mut self, query: String) {
        self.filter_query = query.to_lowercase();
        self.rebuild_lists();
    }

    pub fn handle_event(&mut self, event: NetEvent) {
        match event {
            NetEvent::NmStatus { wifi_enabled, .. } => {
                self.wifi_enabled = wifi_enabled;
                self.header.set_wifi_enabled(wifi_enabled);
                self.rebuild_lists();
            }
            NetEvent::WifiDevice(info) => {
                self.wifi_dev = info;
                self.rebuild_lists();
            }
            NetEvent::EthernetState(info) => {
                self.eth = info;
                self.rebuild_lists();
            }
            NetEvent::ApAdded(info) | NetEvent::ApUpdated(info) => {
                self.aps.insert(info.path.clone(), info);
                self.rebuild_lists();
            }
            NetEvent::ApRemoved(path) => {
                self.aps.remove(&path);
                self.rebuild_lists();
            }
            NetEvent::KnownSsids(list) => {
                self.known = list.into_iter().collect();
                self.rebuild_lists();
            }
            NetEvent::Vpns(list) => {
                self.vpns = list;
                self.rebuild_lists();
            }
            NetEvent::ScanStateChanged(scanning) => {
                self.set_scanning_state(scanning);
            }
            NetEvent::PasswordNeeded { req_id, ssid, security } => {
                PasswordDialog::show(req_id, &ssid, &security, &self.window, self.cmd_tx.clone());
            }
            NetEvent::StatusMessage { text, is_error } => {
                self.status_label.set_text(&text);
                self.status_label.set_visible(true);
                if is_error {
                    self.status_label.remove_css_class("text_white");
                }
            }
        }
        self.update_subtitle();
    }

    fn set_scanning_state(&mut self, scanning: bool) {
        self.scanning = scanning;
        self.header.set_scanning(scanning);
        self.scan_spinner.set_visible(scanning);
        if scanning {
            self.scan_spinner.start();
            self.available_title.set_text("BUSCANDO REDES CERCANAS…");
        } else {
            self.scan_spinner.stop();
            self.available_title.set_text("REDES DISPONIBLES");
        }
        self.rebuild_lists();
    }

    fn update_subtitle(&self) {
        let text = if !self.wifi_enabled {
            "Wi-Fi desactivado".to_string()
        } else if let Some(ssid) = &self.wifi_dev.connected_ssid {
            match &self.wifi_dev.ip {
                Some(ip) => format!("Conectado a {ssid} • {ip}"),
                None => format!("Conectado a {ssid}"),
            }
        } else if self.wifi_dev.activating {
            "Conectando…".to_string()
        } else if self.wifi_dev.present {
            let n = self.aps.len();
            if self.scanning {
                format!("Escaneando redes… ({n} encontradas)")
            } else if n > 0 {
                format!("{n} redes visibles")
            } else {
                "Buscando redes…".to_string()
            }
        } else {
            "Sin dispositivo Wi-Fi".to_string()
        };
        self.header.update_subtitle(&text);
    }

    fn rebuild_lists(&mut self) {
        // Limpiar filas anteriores
        while let Some(child) = self.current_list.first_child() {
            self.current_list.remove(&child);
        }
        while let Some(child) = self.available_list.first_child() {
            self.available_list.remove(&child);
        }
        while let Some(child) = self.eth_list.first_child() {
            self.eth_list.remove(&child);
        }
        while let Some(child) = self.vpn_list.first_child() {
            self.vpn_list.remove(&child);
        }

        // ── Sección Conexión actual: Wi-Fi conectada (o activándose) ──────
        let mut has_current = false;

        if let Some(ssid) = self.wifi_dev.connected_ssid.clone() {
            // Buscar el ApInfo de la red conectada para obtener señal/candado
            let ap_info = self
                .aps
                .values()
                .find(|a| a.ssid == ssid)
                .cloned()
                .unwrap_or_else(|| ApInfo {
                    path: String::new(),
                    ssid: ssid.clone(),
                    strength: 0,
                    secure: false,
                    security_label: "Abierta".into(),
                    frequency: 0,
                });
            let row = NetworkRow::ap(
                &ap_info,
                true,
                self.known.contains(&ssid),
                self.cmd_tx.clone(),
                self.wifi_dev.device_path.clone(),
            );
            self.current_list.append(&row.container);
            has_current = true;
        } else if self.wifi_dev.activating {
            // Tarjeta informativa mientras se conecta
            let row = Box::new(Orientation::Horizontal, 10);
            row.add_css_class("device-card");
            row.add_css_class("connected");
            let text = Label::new(Some("Activando conexión Wi-Fi…"));
            text.add_css_class("device-sub");
            row.append(&text);
            self.current_list.append(&row);
            has_current = true;
        }

        // ── Ethernet activa también vive en "Conexión actual" ─────────────
        let eth_connected = !self.eth.device_path.is_empty() && self.eth.state == 100;
        if eth_connected {
            let row = NetworkRow::ethernet(&self.eth, self.cmd_tx.clone());
            self.current_list.append(&row.container);
            has_current = true;
        }

        self.current_title.set_visible(has_current);
        self.current_box.set_visible(has_current);

        // ── Sección Redes disponibles ─────────────────────────────────────
        if !self.wifi_enabled {
            self.available_header.set_visible(false);
            self.available_list.set_visible(false);
            self.empty_label.set_visible(true);
            self.empty_label.set_text("Wi-Fi desactivado. Actívalo para buscar redes.");
        } else {
            self.available_header.set_visible(true);
            self.available_list.set_visible(true);
            self.empty_label.set_visible(false);

            let query = &self.filter_query;
            let connected_ssid = self.wifi_dev.connected_ssid.clone().unwrap_or_default();
            let mut available: Vec<&ApInfo> = self
                .aps
                .values()
                .filter(|a| a.ssid != connected_ssid)
                .filter(|a| {
                    query.is_empty()
                        || a.ssid.to_lowercase().contains(query)
                        || a.path.to_lowercase().contains(query)
                })
                .collect();

            // Ordenar disponibles: por intensidad de señal descendente, luego A-Z
            available.sort_by(|a, b| {
                b.strength
                    .cmp(&a.strength)
                    .then_with(|| a.ssid.to_lowercase().cmp(&b.ssid.to_lowercase()))
            });

            self.empty_label.set_visible(available.is_empty() && !self.scanning);
            if available.is_empty() && !self.scanning {
                self.empty_label.set_text("No se encontraron redes Wi-Fi.");
            }

            for info in available {
                let row = NetworkRow::ap(
                    info,
                    false,
                    self.known.contains(&info.ssid),
                    self.cmd_tx.clone(),
                    self.wifi_dev.device_path.clone(),
                );
                self.available_list.append(&row.container);
            }
        }

        // ── Sección Ethernet (presente pero sin conexión activa) ──────────
        let eth_present = !self.eth.device_path.is_empty();
        let show_eth = eth_present && !eth_connected;
        self.eth_title.set_visible(show_eth);
        self.eth_list.set_visible(show_eth);
        if show_eth {
            let row = NetworkRow::ethernet(&self.eth, self.cmd_tx.clone());
            self.eth_list.append(&row.container);
        }

        // ── Sección VPN ───────────────────────────────────────────────────
        let has_vpns = !self.vpns.is_empty();
        self.vpn_title.set_visible(has_vpns);
        self.vpn_list.set_visible(has_vpns);
        for vpn in &self.vpns {
            let row = NetworkRow::vpn(vpn, self.cmd_tx.clone());
            self.vpn_list.append(&row.container);
        }
    }
}
