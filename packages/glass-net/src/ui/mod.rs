pub mod icons;
pub mod header;
pub mod network_row;
pub mod password_dialog;
pub mod window;

use std::path::PathBuf;
use std::rc::Rc;
use std::cell::RefCell;
use gtk4::gio;
use gtk4::gio::prelude::*;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{Application, CssProvider};
use crate::events::{NetCommand, NetEvent};
use self::window::NetWindow;

const STYLE_CSS: &str = include_str!("style.css");

/// Resuelve la ruta del ejecutable actual (portable: funciona compilado en dev
/// o instalado a /usr/local/bin, /usr/bin, etc.).
fn current_exe_dir() -> Option<PathBuf> {
    std::env::current_exe().ok().and_then(|p| p.parent().map(PathBuf::from))
}

/// Resuelve la ruta local de style.css de forma portable.
///
/// Estrategia de búsqueda (orden de prioridad):
/// 1. `$XDG_CONFIG_HOME/glass-net/style.css`  (~/.config/glass-net/style.css)
///    → instalación limpia: el CSS vive junto a la config del usuario
/// 2. `DATADIR/glass-net/style.css` donde DATADIR se deriva del ejecutable:
///    - Si el bin está en `/usr/local/bin` → busca `/usr/local/share/glass-net/style.css`
///    - Si el bin está en `/usr/bin`       → busca `/usr/share/glass-net/style.css`
///    - Si el bin está en `.../target/release` → busca `.../src/ui/style.css` (dev)
/// 3. `$HOME/.local/share/glass-net/style.css` (local install)
/// 4. Fallback a `STYLE_CSS` embebido (include_str!)
fn resolve_local_css_path() -> Option<PathBuf> {
    // 1. XDG config
    let config_home = std::env::var("XDG_CONFIG_HOME")
        .ok()
        .or_else(|| std::env::var("HOME").ok().map(|h| format!("{h}/.config")));

    if let Some(ch) = config_home {
        let p = PathBuf::from(format!("{ch}/glass-net/style.css"));
        if p.exists() { return Some(p); }
    }

    // 2. Derivar desde el ejecutable
    if let Some(exe_dir) = current_exe_dir() {
        // Caso desarrollo: .../target/release/glass-net → subir 2 niveles → src/ui/
        if exe_dir.ends_with("target/release") || exe_dir.ends_with("target/debug") {
            let dev_css = exe_dir
                .parent()?.parent()?
                .join("src/ui/style.css");
            if dev_css.exists() { return Some(dev_css); }
        }

        // Caso instalado: /usr/local/bin → /usr/local/share/glass-net/
        //                  /usr/bin       → /usr/share/glass-net/
        if let Some(exe_parent) = exe_dir.parent() {
            let share_css = exe_parent.join("share/glass-net/style.css");
            if share_css.exists() { return Some(share_css); }

            if let Some(grandparent) = exe_parent.parent() {
                let share_css2 = grandparent.join("share/glass-net/style.css");
                if share_css2.exists() { return Some(share_css2); }
            }
        }
    }

    // 3. $HOME/.local/share
    if let Ok(home) = std::env::var("HOME") {
        let p = PathBuf::from(format!("{home}/.local/share/glass-net/style.css"));
        if p.exists() { return Some(p); }
    }

    None
}

fn get_wallust_css_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/c0o0c".to_string());
    PathBuf::from(format!("{home}/.config/waybar/wallust/colors-waybar.css"))
}

fn build_theme_css() -> String {
    let wallust_path = get_wallust_css_path();
    let wallust_palette = std::fs::read_to_string(&wallust_path).unwrap_or_else(|_| {
        "@define-color primary #b0c6ff;\n\
         @define-color on_primary #142f60;\n\
         @define-color primary_container #2e4578;\n\
         @define-color on_primary_container #d9e2ff;\n\
         @define-color secondary #bfc6dc;\n\
         @define-color tertiary #dfbbde;\n\
         @define-color surface #121318;\n\
         @define-color surface_container #1e1f25;\n\
         @define-color on_surface #e2e2e9;\n\
         @define-color foreground #e2e2e9;\n\
         @define-color color14 #b0c6ff;\n\
         @define-color color15 #d9e2ff;\n".to_string()
    });

    // CSS local: intentar resolver dinámicamente, fallback a embebido
    let base_style = resolve_local_css_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .unwrap_or_else(|| STYLE_CSS.to_string());

    format!("{wallust_palette}\n\n{base_style}")
}

pub struct UiApp {
    cmd_tx: async_channel::Sender<NetCommand>,
    event_rx: async_channel::Receiver<NetEvent>,
    use_layer_shell: bool,
    start_hidden: bool,
}

impl UiApp {
    pub fn new(
        cmd_tx: async_channel::Sender<NetCommand>,
        event_rx: async_channel::Receiver<NetEvent>,
        use_layer_shell: bool,
        start_hidden: bool,
    ) -> Self {
        Self { cmd_tx, event_rx, use_layer_shell, start_hidden }
    }

    pub fn run(self) {
        let app = Application::builder()
            .application_id("com.pixi.glassnet")
            .build();

        let cmd_tx = self.cmd_tx;
        let event_rx = self.event_rx;
        let use_layer = self.use_layer_shell;
        let start_hidden = self.start_hidden;

        // ── Vigilante SIGUSR1: toggle instantáneo desde waybar/keybinds ────
        // Un hilo captura la señal y la reenvía por async_channel a una bomba
        // del loop GTK. Con el daemon precargado (autostart --hidden),
        // `pkill -USR1 glass-net` muestra/oculta la ventana al instante.
        let (sig_tx, sig_rx) = async_channel::unbounded::<()>();
        std::thread::Builder::new()
            .name("sigusr1-watch".into())
            .spawn(move || {
                let Ok(mut signals) =
                    signal_hook::iterator::Signals::new([signal_hook::consts::SIGUSR1])
                else {
                    return;
                };
                for _ in signals.forever() {
                    if sig_tx.send_blocking(()).is_err() {
                        break;
                    }
                }
            })
            .expect("Fallo al crear hilo vigilante de SIGUSR1");

        // Slot único de ventana (evita ventanas duplicadas si alguien relanza
        // el binario: la GApplication reenvía la activación a esta instancia)
        let window_slot: Rc<RefCell<Option<Rc<RefCell<NetWindow>>>>> = Rc::new(RefCell::new(None));

        app.connect_startup(|_| {
            let provider = CssProvider::new();
            let initial_css = build_theme_css();
            provider.load_from_data(&initial_css);

            // ── 1. Recarga en caliente al cambiar el Wallpaper (Matugen / Wallust) ──────
            // Monitoreamos el directorio completo para capturar reemplazos atómicos (sed / matugen rename)
            let home = std::env::var("HOME").unwrap_or_else(|_| "/home/c0o0c".to_string());
            let wallust_dir = format!("{home}/.config/waybar/wallust");
            let dir_file = gio::File::for_path(&wallust_dir);
            if let Ok(monitor) = dir_file.monitor_directory(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                let p = provider.clone();
                monitor.connect_changed(move |_, file, _, _| {
                    let name = file.basename().map(|b| b.to_string_lossy().to_string()).unwrap_or_default();
                    if name == "colors-waybar.css" || name.contains("colors") {
                        let new_css = build_theme_css();
                        p.load_from_data(&new_css);
                    }
                });
            }

            // Monitoreo directo del archivo por si el FS emite eventos de archivo individual
            let wallust_path = get_wallust_css_path();
            let wallust_file = gio::File::for_path(&wallust_path);
            if let Ok(monitor) = wallust_file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                let p = provider.clone();
                monitor.connect_changed(move |_, _, _, _| {
                    let new_css = build_theme_css();
                    p.load_from_data(&new_css);
                });
            }

            // ── 2. Recarga en caliente al editar style.css ──────────────
            // La ruta se resuelve dinámicamente (mismo orden que build_theme_css)
            if let Some(css_path) = resolve_local_css_path() {
                let file = gio::File::for_path(css_path);
                if let Ok(monitor) = file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
                    let p = provider.clone();
                    monitor.connect_changed(move |_, _, _, event| {
                        if event == gio::FileMonitorEvent::ChangesDoneHint || event == gio::FileMonitorEvent::Changed {
                            let new_css = build_theme_css();
                            p.load_from_data(&new_css);
                        }
                    });
                }
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
            let slot_for_activate = window_slot.clone();

            // Si la ventana ya existe (relanzamiento del binario), solo mostrarla
            if let Some(win) = slot_for_activate.borrow().clone() {
                win.borrow().window.present();
                let _ = cmd_tx.send_blocking(NetCommand::SetVisible(true));
                return;
            }

            let net_window = Rc::new(RefCell::new(NetWindow::new(app, cmd_tx.clone(), use_layer)));
            *slot_for_activate.borrow_mut() = Some(net_window.clone());

            // Conectar el buscador
            {
                let win_for_search = net_window.clone();
                let search_entry = net_window.borrow().search_entry.clone();
                search_entry.connect_changed(move |entry| {
                    win_for_search.borrow_mut().set_filter(entry.text().to_string());
                });
            }

            // Consumidor de eventos de NetworkManager en el loop de GTK
            let rx = event_rx.clone();
            let win_for_events = net_window.clone();
            glib::spawn_future_local(async move {
                while let Ok(event) = rx.recv().await {
                    win_for_events.borrow_mut().handle_event(event);
                }
            });

            // Bomba SIGUSR1: alternar visibilidad al instante (modo daemon)
            let sig_rx = sig_rx.clone();
            let win_for_signals = net_window.clone();
            let tx_for_signals = cmd_tx.clone();
            glib::spawn_future_local(async move {
                while sig_rx.recv().await.is_ok() {
                    let visible = win_for_signals.borrow().window.is_visible();
                    if visible {
                        win_for_signals.borrow().window.hide();
                        let _ = tx_for_signals.send_blocking(NetCommand::SetVisible(false));
                    } else {
                        win_for_signals.borrow().window.present();
                        let _ = tx_for_signals.send_blocking(NetCommand::SetVisible(true));
                    }
                }
            });

            // --hidden (autostart del daemon): no presentar la ventana
            if !start_hidden {
                net_window.borrow().window.present();
                let _ = cmd_tx.send_blocking(NetCommand::SetVisible(true));
            }
        });

        app.run_with_args::<String>(&[]);
    }
}
