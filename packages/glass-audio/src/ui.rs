//! UI del control de volumen.

use std::rc::Rc;
use std::cell::RefCell;

use async_channel::{Receiver, Sender};
use audio_core::{AudioCommand, AudioState, SinkInfo};
use glass_theme::{glass_panel, section_label, panel_title, panel_subtitle, device_card, icon_squircle};
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

        // Output page
        let output_scrolled = ScrolledWindow::builder()
            .hscrollbar_policy(gtk4::PolicyType::Never)
            .vscrollbar_policy(gtk4::PolicyType::External)
            .has_frame(false)
            .min_content_height(360)
            .propagate_natural_height(true)
            .build();

        let output_container = GtkBox::new(Orientation::Vertical, 4);
        output_container.set_margin_bottom(16);

        let output_section = section_label("DISPOSITIVOS DE SALIDA");
        output_container.append(&output_section);

        output_scrolled.set_child(Some(&output_container));
        notebook.append_page(&output_scrolled, Some(&Label::new(Some("Salida"))));

        // Other tabs (placeholders)
        for tab_name in &["Entrada", "Reproducción", "Grabación", "Configuración"] {
            let scrolled = ScrolledWindow::builder()
                .hscrollbar_policy(gtk4::PolicyType::Never)
                .vscrollbar_policy(gtk4::PolicyType::External)
                .has_frame(false)
                .min_content_height(360)
                .propagate_natural_height(true)
                .build();
            let container = GtkBox::new(Orientation::Vertical, 4);
            let section = section_label(&format!("{}", tab_name.to_uppercase()));
            container.append(&section);
            let placeholder = Label::new(Some("Próximamente..."));
            placeholder.add_css_class("device-sub");
            container.append(&placeholder);
            scrolled.set_child(Some(&container));
            notebook.append_page(&scrolled, Some(&Label::new(Some(tab_name))));
        }

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

        // Process events from audio service
        let output_container_clone = output_container.clone();
        let cmd_tx_clone = cmd_tx.clone();
        glib::timeout_add_local(std::time::Duration::from_millis(100), move || {
            while let Ok(state) = event_rx.try_recv() {
                // Clear existing sinks
                while let Some(child) = output_container_clone.first_child() {
                    output_container_clone.remove(&child);
                }
                let section = section_label("DISPOSITIVOS DE SALIDA");
                output_container_clone.append(&section);

                for sink in &state.sinks {
                    let card = device_card();
                    card.set_orientation(Orientation::Vertical);
                    card.set_spacing(8);

                    // Header row: icon + name + mute button
                    let header_row = GtkBox::new(Orientation::Horizontal, 8);
                    header_row.set_valign(gtk4::Align::Center);

                    let squircle = icon_squircle("🔊", "speaker");
                    header_row.append(&squircle);

                    let name_label = Label::new(Some(&sink.description));
                    name_label.add_css_class("device-name");
                    name_label.set_halign(gtk4::Align::Start);
                    name_label.set_hexpand(true);
                    header_row.append(&name_label);

                    let mute_btn = gtk4::Button::new();
                    mute_btn.set_label(if sink.muted { "🔇" } else { "🔊" });
                    mute_btn.add_css_class("btn-scan");
                    let cmd_tx_mute = cmd_tx_clone.clone();
                    let sink_idx = sink.index;
                    let is_muted = sink.muted;
                    mute_btn.connect_clicked(move |_| {
                        let _ = cmd_tx_mute.send_blocking(AudioCommand::SetMute {
                            target: audio_core::commands::VolumeTarget::Sink(sink_idx),
                            muted: !is_muted,
                        });
                    });
                    header_row.append(&mute_btn);

                    card.append(&header_row);

                    // Volume slider
                    let slider_row = GtkBox::new(Orientation::Horizontal, 8);
                    slider_row.set_valign(gtk4::Align::Center);

                    let vol_label = Label::new(Some("Silencio"));
                    vol_label.add_css_class("device-sub");
                    vol_label.set_width_chars(8);
                    slider_row.append(&vol_label);

                    let adj = Adjustment::new(
                        (sink.volume * 100.0) as f64,
                        0.0,
                        150.0,
                        1.0,
                        5.0,
                        0.0,
                    );
                    let scale = Scale::new(gtk4::Orientation::Horizontal, Some(&adj));
                    scale.set_hexpand(true);
                    scale.set_draw_value(false);
                    scale.add_css_class("volume-slider");

                    let percent_label = Label::new(Some(&format!("{:.0}% ({:.2} dB)", sink.volume * 100.0, 0.0)));
                    percent_label.add_css_class("device-sub");
                    percent_label.set_width_chars(14);

                    let cmd_tx_vol = cmd_tx_clone.clone();
                    let sink_idx_vol = sink.index;
                    scale.connect_value_changed(move |s| {
                        let vol = s.value() as f32 / 100.0;
                        let _ = cmd_tx_vol.send_blocking(AudioCommand::SetVolume {
                            target: audio_core::commands::VolumeTarget::Sink(sink_idx_vol),
                            volume: vol,
                        });
                    });

                    slider_row.append(&scale);
                    slider_row.append(&percent_label);

                    card.append(&slider_row);

                    // 100% mark
                    let mark_label = Label::new(Some("100% (0.00 dB)"));
                    mark_label.add_css_class("device-sub");
                    mark_label.set_halign(gtk4::Align::End);
                    card.append(&mark_label);

                    output_container_clone.append(&card);
                }
            }
            glib::ControlFlow::Continue
        });

        Self { window }
    }
}