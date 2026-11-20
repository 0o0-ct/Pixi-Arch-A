//! UI del control de volumen.

use std::rc::Rc;
use std::cell::RefCell;

use async_channel::{Receiver, Sender};
use audio_core::{AudioCommand, AudioState, SinkInfo, SourceInfo};
use glass_theme::{glass_panel, section_label, panel_title, panel_subtitle, device_card, icon_squircle, action_button};
use gtk4::prelude::*;
use gtk4::{
    Application, ApplicationWindow, Box as GtkBox, Label, Notebook, Orientation,
    ScrolledWindow, Scale, Adjustment,
};

pub struct AudioWindow {
    pub window: ApplicationWindow,
}

impl AudioWindow {
    pub fn new(
        app: &Application,
        cmd_tx: Sender<AudioCommand>,
        event_rx: Receiver<AudioState>,
    ) -> Self {
        let window = ApplicationWindow::builder()
            .application(app)
            .title("Control de Volumen")
            .default_width(560)
            .default_height(720)
            .decorated(false)
            .build();

        let main_panel = glass_panel(Orientation::Vertical, 10);

        // Header
        let title = panel_title("Control de Volumen");
        main_panel.append(&title);

        let subtitle = panel_subtitle("PipeWire / PulseAudio");
        main_panel.append(&subtitle);

        // Tabs
        let notebook = Notebook::new();
        notebook.set_tab_pos(gtk4::PositionType::Top);

        // Tab 1: Salida (Output devices)
        let output_page = create_output_page(cmd_tx.clone());
        notebook.append_page(&output_page, Some(&Label::new(Some("Salida"))));

        // Tab 2: Entrada (Input devices)
        let input_page = create_input_page(cmd_tx.clone());
        notebook.append_page(&input_page, Some(&Label::new(Some("Entrada"))));

        // Tab 3: Reproducción (Playback streams)
        let playback_page = create_playback_page(cmd_tx.clone());
        notebook.append_page(&playback_page, Some(&Label::new(Some("Reproducción"))));

        // Tab 4: Grabación (Record streams)
        let record_page = create_record_page(cmd_tx.clone());
        notebook.append_page(&record_page, Some(&Label::new(Some("Grabación"))));

        // Tab 5: Configuración (Cards)
        let config_page = create_config_page(cmd_tx.clone());
        notebook.append_page(&config_page, Some(&Label::new(Some("Configuración"))));

        main_panel.append(&notebook);

        let root_box = GtkBox::new(Orientation::Vertical, 0);
        root_box.set_hexpand(true);
        root_box.set_vexpand(true);
        root_box.set_halign(gtk4::Align::Fill);
        root_box.set_valign(gtk4::Align::Fill);

        main_panel.set_halign(gtk4::Align::Center);
        main_panel.set_valign(gtk4::Align::Center);
        main_panel.set_hexpand(false);
        main_panel.set_vexpand(true);
        main_panel.set_size_request(520, -1);

        root_box.append(&main_panel);
        window.set_child(Some(&root_box));

        // Escape to close
        let key_controller = gtk4::EventControllerKey::new();
        let win_esc = window.clone();
        key_controller.connect_key_pressed(move |_, keyval, _, _| {
            if keyval == gtk4::gdk::Key::Escape {
                win_esc.close();
                gtk4::glib::Propagation::Stop
            } else {
                gtk4::glib::Propagation::Proceed
            }
        });
        window.add_controller(key_controller);

        Self { window }
    }
}

fn create_output_page(cmd_tx: Sender<AudioCommand>) -> ScrolledWindow {
    let scrolled = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::External)
        .has_frame(false)
        .min_content_height(360)
        .propagate_natural_height(true)
        .build();

    let list_container = GtkBox::new(Orientation::Vertical, 4);
    list_container.set_margin_bottom(16);

    let section = section_label("DISPOSITIVOS DE SALIDA");
    list_container.append(&section);

    // Placeholder for sinks - will be populated by events
    let placeholder = Label::new(Some("Cargando dispositivos..."));
    placeholder.add_css_class("device-sub");
    list_container.append(&placeholder);

    scrolled.set_child(Some(&list_container));
    scrolled
}

fn create_input_page(cmd_tx: Sender<AudioCommand>) -> ScrolledWindow {
    let scrolled = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::External)
        .has_frame(false)
        .min_content_height(360)
        .propagate_natural_height(true)
        .build();

    let list_container = GtkBox::new(Orientation::Vertical, 4);
    let section = section_label("DISPOSITIVOS DE ENTRADA");
    list_container.append(&section);

    let placeholder = Label::new(Some("Cargando dispositivos..."));
    placeholder.add_css_class("device-sub");
    list_container.append(&placeholder);

    scrolled.set_child(Some(&list_container));
    scrolled
}

fn create_playback_page(cmd_tx: Sender<AudioCommand>) -> ScrolledWindow {
    let scrolled = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::External)
        .has_frame(false)
        .min_content_height(360)
        .propagate_natural_height(true)
        .build();

    let list_container = GtkBox::new(Orientation::Vertical, 4);
    let section = section_label("FLUJOS DE REPRODUCCIÓN");
    list_container.append(&section);

    let placeholder = Label::new(Some("No hay aplicaciones reproduciendo audio"));
    placeholder.add_css_class("device-sub");
    list_container.append(&placeholder);

    scrolled.set_child(Some(&list_container));
    scrolled
}

fn create_record_page(cmd_tx: Sender<AudioCommand>) -> ScrolledWindow {
    let scrolled = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::External)
        .has_frame(false)
        .min_content_height(360)
        .propagate_natural_height(true)
        .build();

    let list_container = GtkBox::new(Orientation::Vertical, 4);
    let section = section_label("FLUJOS DE GRABACIÓN");
    list_container.append(&section);

    let placeholder = Label::new(Some("No hay aplicaciones grabando audio"));
    placeholder.add_css_class("device-sub");
    list_container.append(&placeholder);

    scrolled.set_child(Some(&list_container));
    scrolled
}

fn create_config_page(cmd_tx: Sender<AudioCommand>) -> ScrolledWindow {
    let scrolled = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::External)
        .has_frame(false)
        .min_content_height(360)
        .propagate_natural_height(true)
        .build();

    let list_container = GtkBox::new(Orientation::Vertical, 4);
    let section = section_label("CONFIGURACIÓN DE AUDIO");
    list_container.append(&section);

    let placeholder = Label::new(Some("Cargando tarjetas de audio..."));
    placeholder.add_css_class("device-sub");
    list_container.append(&placeholder);

    scrolled.set_child(Some(&list_container));
    scrolled
}