pub mod icons;
pub mod header;
pub mod device_row;
pub mod pairing_dialog;
pub mod window;

use std::rc::Rc;
use std::cell::RefCell;
use gtk4::gio;
use gtk4::gio::prelude::*;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{Application, CssProvider};
use crate::events::{BtCommand, BtEvent};
use self::window::BtWindow;

const STYLE_CSS: &str = include_str!("style.css");

fn get_wallust_css_path() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/c0o0c".to_string());
    format!("{home}/.config/waybar/wallust/colors-waybar.css")
}

fn build_theme_css() -> String {
    let wallust_path = get_wallust_css_path();
    let wallust_palette = std::fs::read_to_string(&wallust_path).unwrap_or_else(|_| {
        "@define-color primary #67FFF0;\n\
         @define-color on_primary #003734;\n\
         @define-color primary_container #004f4b;\n\
         @define-color on_primary_container #e0fffa;\n\
         @define-color secondary #a8eae2;\n\
         @define-color tertiary #ffd9e1;\n\
         @define-color surface #10141e;\n\
         @define-color surface_container #1a1e28;\n\
         @define-color on_surface #e7e0e8;\n\
         @define-color foreground #e7e0e8;\n\
         @define-color color14 #67FFF0;\n\
         @define-color color15 #e0fffa;\n".to_string()
    });

    let dev_css_path = "/home/c0o0c/Proyectos/glass-bt/src/ui/style.css";
    let base_style = std::fs::read_to_string(dev_css_path).unwrap_or_else(|_| STYLE_CSS.to_string());

    format!("{wallust_palette}\n\n{base_style}")
}

pub struct UiApp {
    cmd_tx: async_channel::Sender<BtCommand>,
    event_rx: async_channel::Receiver<BtEvent>,
    use_layer_shell: bool,
}

impl UiApp {
    pub fn new(
        cmd_tx: async_channel::Sender<BtCommand>,
        event_rx: async_channel::Receiver<BtEvent>,
        use_layer_shell: bool,
    ) -> Self {
        Self { cmd_tx, event_rx, use_layer_shell }
    }

    pub fn run(self) {
        let app = Application::builder()
            .application_id("com.pixi.glassbt")
            .build();

        let cmd_tx = self.cmd_tx;
        let event_rx = self.event_rx;
        let use_layer = self.use_layer_shell;

        app.connect_startup(|_| {
            let provider = CssProvider::new();
            let initial_css = build_theme_css();
            provider.load_from_data(&initial_css);

            // ── 1. Recarga en caliente al cambiar el Wallpaper (Wallust) ──────
            let wallust_path = get_wallust_css_path();
            let wallust_file = gio::File::for_path(&wallust_path);
            if let Ok(monitor) = wallust_file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                let p = provider.clone();
                monitor.connect_changed(move |_, _, _, event| {
                    if event == gio::FileMonitorEvent::ChangesDoneHint || event == gio::FileMonitorEvent::Changed {
                        let new_css = build_theme_css();
                        p.load_from_data(&new_css);
                    }
                });
            }

            // ── 2. Recarga en caliente al editar src/ui/style.css ──────────────
            let dev_css_path = "/home/c0o0c/Proyectos/glass-bt/src/ui/style.css";
            let file = gio::File::for_path(dev_css_path);
            if let Ok(monitor) = file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                let p = provider.clone();
                monitor.connect_changed(move |_, _, _, event| {
                    if event == gio::FileMonitorEvent::ChangesDoneHint || event == gio::FileMonitorEvent::Changed {
                        let new_css = build_theme_css();
                        p.load_from_data(&new_css);
                    }
                });
            }

            if let Some(display) = gtk4::gdk::Display::default() {
                gtk4::style_context_add_provider_for_display(
                    &display,
                    &provider,
                    gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION + 200,
                );
            }
        });

        app.connect_activate(move |app| {
            let bt_window = Rc::new(RefCell::new(BtWindow::new(app, cmd_tx.clone(), use_layer)));

            // Conectar el buscador
            {
                let win_for_search = bt_window.clone();
                let search_entry = bt_window.borrow().search_entry.clone();
                search_entry.connect_changed(move |entry| {
                    win_for_search.borrow_mut().set_filter(entry.text().to_string());
                });
            }

            // Iniciar consumidor de eventos de BlueZ en el loop de GTK
            let rx = event_rx.clone();
            let win_for_events = bt_window.clone();

            glib::spawn_future_local(async move {
                while let Ok(event) = rx.recv().await {
                    win_for_events.borrow_mut().handle_event(event);
                }
            });

            bt_window.borrow().window.present();
        });

        app.run_with_args::<String>(&[]);
    }
}
