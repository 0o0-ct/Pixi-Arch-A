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
            let dev_css_path = "/home/c0o0c/Proyectos/glass-bt/src/ui/style.css";

            if let Ok(css) = std::fs::read_to_string(dev_css_path) {
                provider.load_from_data(&css);
            } else {
                provider.load_from_data(STYLE_CSS);
            }

            // ── Recarga en caliente del CSS (GIO FileMonitor) ─────────────
            let file = gio::File::for_path(dev_css_path);
            if let Ok(monitor) = file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                let p = provider.clone();
                let path_str = dev_css_path.to_string();
                monitor.connect_changed(move |_, _, _, event| {
                    if (event == gio::FileMonitorEvent::ChangesDoneHint || event == gio::FileMonitorEvent::Changed)
                        && let Ok(new_css) = std::fs::read_to_string(&path_str) {
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
                search_entry.connect_search_changed(move |entry| {
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
