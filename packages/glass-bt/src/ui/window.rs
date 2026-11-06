use std::collections::HashMap;
use gtk4::prelude::*;
use gtk4::{
    glib, Application, ApplicationWindow, Box, EventControllerKey, Label, ListBox,
    Orientation, ScrolledWindow, SearchEntry, Spinner,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use crate::events::{BtCommand, BtEvent, DeviceInfo};
use super::header::Header;
use super::device_row::DeviceRow;
use super::pairing_dialog::PairingDialog;

pub struct BtWindow {
    pub window: ApplicationWindow,
    pub search_entry: SearchEntry,
    header: Header,
    status_label: Label,
    paired_list: ListBox,
    available_list: ListBox,
    unknown_list: ListBox,
    available_title: Label,
    unknown_title: Label,
    scan_spinner: Spinner,
    paired_empty_label: Label,
    cmd_tx: async_channel::Sender<BtCommand>,
    devices: HashMap<String, DeviceInfo>,
    is_powered: bool,
    filter_query: String,
}

impl BtWindow {
    pub fn new(app: &Application, cmd_tx: async_channel::Sender<BtCommand>, use_layer_shell: bool) -> Self {
        let window = ApplicationWindow::builder()
            .application(app)
            .title("Bluetooth")
            .default_width(460)
            .default_height(640)
            .decorated(false)
            .build();

        // ── Si se solicita modo layer-shell con flag --layer ──────────────
        if use_layer_shell {
            window.init_layer_shell();
            window.set_namespace(Some("bt-glass"));
            window.set_layer(Layer::Overlay);
            window.set_keyboard_mode(KeyboardMode::OnDemand);
            window.set_anchor(Edge::Top, true);
            window.set_anchor(Edge::Right, true);
            window.set_margin(Edge::Top, 12);
            window.set_margin(Edge::Right, 16);
        }

        // ── Atajo de teclado: Escape cierra la aplicación ─────────────────
        let key_controller = EventControllerKey::new();
        let app_esc = app.clone();
        key_controller.connect_key_pressed(move |_, keyval, _, _| {
            if keyval == gtk4::gdk::Key::Escape {
                app_esc.quit();
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

        // Conectar botón de cerrar integrado en la cabecera
        let app_close = app.clone();
        header.close_button.connect_clicked(move |_| {
            app_close.quit();
        });

        main_panel.append(&header.container);

        // Barra de búsqueda rápida
        let search_entry = SearchEntry::new();
        search_entry.add_css_class("glass-search");
        search_entry.set_placeholder_text(Some("Buscar dispositivo o dirección MAC..."));
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

        // Sección 1: Dispositivos Guardados
        let paired_title = Label::new(Some("DISPOSITIVOS GUARDADOS"));
        paired_title.set_halign(gtk4::Align::Start);
        paired_title.add_css_class("section-title");
        list_container.append(&paired_title);

        let paired_empty_label = Label::new(Some("No hay dispositivos vinculados guardados."));
        paired_empty_label.add_css_class("device-sub");
        paired_empty_label.set_halign(gtk4::Align::Start);
        paired_empty_label.set_margin_top(4);
        paired_empty_label.set_margin_bottom(6);
        list_container.append(&paired_empty_label);

        let paired_list = ListBox::new();
        paired_list.set_selection_mode(gtk4::SelectionMode::None);
        paired_list.add_css_class("device-list");
        list_container.append(&paired_list);

        // Sección 2: Dispositivos Cercanos (Disponibles)
        let available_header = Box::new(Orientation::Horizontal, 8);
        available_header.set_valign(gtk4::Align::Center);

        let available_title = Label::new(Some("DISPOSITIVOS DISPONIBLES"));
        available_title.set_halign(gtk4::Align::Start);
        available_title.add_css_class("section-title");
        available_header.append(&available_title);

        let scan_spinner = Spinner::new();
        scan_spinner.set_size_request(14, 14);
        scan_spinner.set_valign(gtk4::Align::Center);
        scan_spinner.set_visible(false);
        available_header.append(&scan_spinner);

        list_container.append(&available_header);

        let available_list = ListBox::new();
        available_list.set_selection_mode(gtk4::SelectionMode::None);
        available_list.add_css_class("device-list");
        list_container.append(&available_list);

        // Sección 3: Dispositivos Desconocidos (Solo MAC)
        let unknown_title = Label::new(Some("DESCONOCIDOS"));
        unknown_title.set_halign(gtk4::Align::Start);
        unknown_title.add_css_class("section-title");
        unknown_title.set_visible(false);
        list_container.append(&unknown_title);

        let unknown_list = ListBox::new();
        unknown_list.set_selection_mode(gtk4::SelectionMode::None);
        unknown_list.add_css_class("device-list");
        unknown_list.set_visible(false);
        list_container.append(&unknown_list);

        scrolled.set_child(Some(&list_container));
        main_panel.append(&scrolled);

        window.set_child(Some(&main_panel));

        Self {
            window,
            search_entry,
            header,
            status_label,
            paired_list,
            available_list,
            unknown_list,
            available_title,
            unknown_title,
            scan_spinner,
            paired_empty_label,
            cmd_tx,
            devices: HashMap::new(),
            is_powered: false,
            filter_query: String::new(),
        }
    }

    pub fn set_filter(&mut self, query: String) {
        self.filter_query = query.to_lowercase();
        self.rebuild_lists();
    }

    pub fn handle_event(&mut self, event: BtEvent) {
        match event {
            BtEvent::AdapterStatus { powered, discovering, .. } => {
                self.is_powered = powered;
                self.header.set_powered(powered);
                self.set_scanning_state(discovering);
                self.update_header_counts();
                self.rebuild_lists();
            }
            BtEvent::ScanStateChanged(scanning) => {
                self.set_scanning_state(scanning);
            }
            BtEvent::DeviceAdded(info) => {
                self.devices.insert(info.mac.clone(), info);
                self.update_header_counts();
                self.rebuild_lists();
            }
            BtEvent::DeviceUpdated(info) => {
                self.devices.insert(info.mac.clone(), info);
                self.update_header_counts();
                self.rebuild_lists();
            }
            BtEvent::DeviceRemoved(mac) => {
                self.devices.remove(&mac);
                self.update_header_counts();
                self.rebuild_lists();
            }
            BtEvent::PairingPrompt(req) => {
                PairingDialog::show(req, &self.window, self.cmd_tx.clone());
            }
            BtEvent::StatusMessage { text, is_error } => {
                self.status_label.set_text(&text);
                self.status_label.set_visible(true);
                if is_error {
                    self.status_label.remove_css_class("text_white");
                }
            }
        }
    }

    fn set_scanning_state(&mut self, scanning: bool) {
        self.header.set_scanning(scanning);
        self.scan_spinner.set_visible(scanning);
        if scanning {
            self.scan_spinner.start();
            self.available_title.set_text("BUSCANDO DISPOSITIVOS CERCANOS…");
        } else {
            self.scan_spinner.stop();
            self.available_title.set_text("DISPOSITIVOS DISPONIBLES");
        }
    }

    fn update_header_counts(&self) {
        let paired_count = self.devices.values().filter(|d| d.paired).count();
        let connected_count = self.devices.values().filter(|d| d.connected).count();
        self.header.update_counts(paired_count, connected_count, self.is_powered);
    }

    fn rebuild_lists(&self) {
        // Limpiar filas anteriores
        while let Some(child) = self.paired_list.first_child() {
            self.paired_list.remove(&child);
        }
        while let Some(child) = self.available_list.first_child() {
            self.available_list.remove(&child);
        }
        while let Some(child) = self.unknown_list.first_child() {
            self.unknown_list.remove(&child);
        }

        if !self.is_powered {
            self.paired_empty_label.set_text("El Bluetooth está apagado.");
            self.paired_empty_label.set_visible(true);
            self.available_title.set_visible(false);
            self.available_list.set_visible(false);
            self.unknown_title.set_visible(false);
            self.unknown_list.set_visible(false);
            return;
        }

        self.available_title.set_visible(true);
        self.available_list.set_visible(true);

        let query = &self.filter_query;
        let mut paired_devices = Vec::new();
        let mut available_devices = Vec::new();
        let mut unknown_devices = Vec::new();

        for dev in self.devices.values() {
            let name = dev.alias.as_deref().unwrap_or(&dev.name);
            if !query.is_empty()
                && !name.to_lowercase().contains(query)
                && !dev.mac.to_lowercase().contains(query)
            {
                continue;
            }

            if dev.paired {
                paired_devices.push(dev);
            } else {
                let is_mac_only = dev.name.replace(':', "-") == dev.mac.replace(':', "-")
                    || dev.name.trim().is_empty();

                if is_mac_only {
                    unknown_devices.push(dev);
                } else {
                    available_devices.push(dev);
                }
            }
        }

        // Ordenar guardados: conectados primero, luego alfabéticamente
        paired_devices.sort_by(|a, b| {
            b.connected
                .cmp(&a.connected)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });

        // Ordenar disponibles: por intensidad de señal (RSSI) descendente
        available_devices.sort_by(|a, b| {
            let r_a = a.rssi.unwrap_or(i16::MIN);
            let r_b = b.rssi.unwrap_or(i16::MIN);
            r_b.cmp(&r_a).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });

        self.paired_empty_label.set_visible(paired_devices.is_empty());
        if paired_devices.is_empty() {
            self.paired_empty_label.set_text("No hay dispositivos vinculados.");
        }

        for dev in paired_devices {
            let row = DeviceRow::new(dev, self.cmd_tx.clone());
            self.paired_list.append(&row.container);
        }

        self.available_list.set_visible(!available_devices.is_empty());
        for dev in available_devices {
            let row = DeviceRow::new(dev, self.cmd_tx.clone());
            self.available_list.append(&row.container);
        }

        // Desconocidos agrupados
        let has_unknown = !unknown_devices.is_empty();
        self.unknown_title.set_visible(has_unknown);
        self.unknown_list.set_visible(has_unknown);

        for dev in unknown_devices {
            let row = DeviceRow::new(dev, self.cmd_tx.clone());
            self.unknown_list.append(&row.container);
        }
    }
}
