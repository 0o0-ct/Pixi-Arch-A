//! # glass-audio v2.0 - Quick Settings (Panel de Ajustes Rápidos)
//!
//! Panel tipo Quick Settings / Control Center con estética ONE UI 8.5 + Glassmorphism.
//!
//! Construcción:
//!   cd packages && cargo build --release -p glass-audio
//!
//! Uso:
//!   glass-audio              # Abre el panel
//!   glass-audio --dump       # Imprime estado del audio como JSON

use gtk4::prelude::*;
use gtk4::{
    Application, ApplicationWindow, Box as GtkBox, Grid, Image, Label, Orientation, Scale,
    Adjustment,
};

use audio_core::{AudioCommand, AudioService, AudioState, DeviceType, VolumeTarget};

mod ui;

use ui::SmartDevice;

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use async_channel::unbounded;

/// Estado global del Quick Settings Panel.
#[derive(Clone)]
pub struct QuickSettingsState {
    pub edit_mode: Rc<Cell<bool>>,
    pub brightness: Rc<Cell<f32>>,
    pub volume: Rc<Cell<f32>>,
    pub audio_state: Rc<RefCell<AudioState>>,
    pub cmd_tx: Rc<async_channel::Sender<AudioCommand>>,
    pub smart_devices: Rc<RefCell<Vec<SmartDevice>>>,
}

impl QuickSettingsState {
    pub fn new(cmd_tx: Rc<async_channel::Sender<AudioCommand>>) -> Self {
        Self {
            edit_mode: Rc::new(Cell::new(false)),
            brightness: Rc::new(Cell::new(50.0)),
            volume: Rc::new(Cell::new(50.0)),
            audio_state: Rc::new(RefCell::new(AudioState::default())),
            cmd_tx,
            smart_devices: Rc::new(RefCell::new(vec![
                SmartDevice {
                    id: "watch-001".into(),
                    name: "MyWatch".into(),
                    location: "C 262m".into(),
                    icon: "other-watch".into(),
                },
                SmartDevice {
                    id: "speaker-002".into(),
                    name: "Livingroom Speaker".into(),
                    location: "Home".into(),
                    icon: "other-speaker".into(),
                },
                SmartDevice {
                    id: "vacuum-003".into(),
                    name: "Robot Vacuum".into(),
                    location: "Main St 200m".into(),
                    icon: "other-vacuum".into(),
                },
            ])),
        }
    }

    pub fn set_volume(&self, p: f32) {
        let v = (p / 100.0 * 150.0) as f32;
        let _ = self.cmd_tx.send_blocking(AudioCommand::SetVolume {
            target: VolumeTarget::Sink(0),
            volume: v,
            channels: 2,
        });
    }
}

/// Start audio poller thread.
fn start_audio_poller(
    cmd_tx: Rc<async_channel::Sender<AudioCommand>>,
    state: Rc<QuickSettingsState>,
    event_rx: async_channel::Receiver<AudioState>,
) {
    glib::spawn_future_local(async move {
        loop {
            match event_rx.recv().await {
                Ok(s) => {
                    let vol = s
                        .sinks
                        .first()
                        .map(|x| x.volume * 100.0)
                        .unwrap_or(50.0);
                    state.volume.set(vol);
                    *state.audio_state.borrow_mut() = s;
                }
                Err(_) => break,
            }
        }
    });
}



/// Build the main window with all Quick Settings components.
fn build_quick_settings_window(app: &Application, state: Rc<QuickSettingsState>, width: i32) -> ApplicationWindow {
    let window = ApplicationWindow::new(app);

    let root = GtkBox::new(Orientation::Vertical, 0);
    root.add_css_class("qs-root");

    let main_area = GtkBox::new(Orientation::Vertical, 0);
    main_area.add_css_class("qs-main-area");
    main_area.set_hexpand(true);
    main_area.set_vexpand(true);

    // Status Bar
    let status_bar = ui::build_status_bar(state.clone());
    main_area.append(&status_bar);

    // Header Actions
    let header_actions = ui::build_header_actions(state.clone());
    main_area.append(&header_actions);

    // Control Grid
    let grid = ui::build_control_grid(state.clone());
    main_area.append(&grid);

    // Sliders
    let brightness = ui::build_brightness_slider(state.clone());
    main_area.append(&brightness);
    let volume = ui::build_volume_slider(state.clone());
    main_area.append(&volume);

    // Smart Devices
    let devices = ui::build_device_status_card(state.clone());
    main_area.append(&devices);

    // Edit Mode Bar (show when edit_mode is on)
    let edit_bar = ui::build_edit_mode_bar(state.clone());
    main_area.append(&edit_bar);

    root.append(&main_area);
    window.set_child(Some(&root));
    window
}

fn main() {
    // Inicializar GTK
    gtk4::init();

    // Inicializar glass-theme
    glass_theme::init_theme();

    // Parser de args
    let args: Vec<String> = std::env::args().collect();
    let width: i32 = args
        .iter()
        .position(|a| a == "--width")
        .and_then(|i| args.get(i + 1).and_then(|s| s.parse().ok()))
        .unwrap_or(720);

    // Modo dump
    if args.iter().any(|a| a == "--dump") {
        run_dump();
        return;
    }

    // Inicializar logging
    let _ = tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .try_init();

    let app = Application::builder()
        .application_id("com.pixi.glassaudio-qs")
        .build();

    // Audio Service Setup
    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();

    let state_rc: Rc<RefCell<Option<Rc<QuickSettingsState>>>> = Rc::new(RefCell::new(None));

    // Hilo de AudioService
    let event_tx_cloned = event_tx;
    let ping_tx = cmd_tx.clone();
    std::thread::Builder::new()
        .name("audio-qs-service".into())
        .spawn(move || {
            let service = AudioService::new(cmd_rx, ping_tx, event_tx_cloned);
            service.run();
        })
        .expect("Hilo AudioService");

    let cmd_tx_main = Rc::new(cmd_tx);

    // Start audio poller immediately (before app starts)
    let state_pre = Rc::new(QuickSettingsState::new(cmd_tx_main.clone()));
    start_audio_poller(cmd_tx_main.clone(), state_pre.clone(), event_rx);
    *state_rc.borrow_mut() = Some(state_pre.clone());

    // on_startup: usar estado ya creado
    let state_ptr = state_rc.clone();
    app.connect_startup(move |_| {
        let state = state_ptr.borrow().clone().expect("Estado no creado");
        let state_cloned = state.clone();

        // Timeout para mantener UI actualizada
        glib::timeout_add_seconds_local(2, move || {
            if let Some(s) = state_cloned.audio_state.borrow().sinks.first() {
                state_cloned.volume.set(s.volume * 100.0);
            }
            glib::ControlFlow::Continue
        });
    });

    // on_activate: build window
    let state_ptr2 = state_rc.clone();
    app.connect_activate(move |app| {
        let Some(state) = state_ptr2.borrow().clone() else {
            eprintln!("Estado no disponible, saliendo...");
            return;
        };

        let window = build_quick_settings_window(app, state, width);
        window.set_title(Some("Ajustes Rápidos"));
        window.set_resizable(false);
        window.set_size_request(width, 520);
        window.set_default_size(width, 520);
        window.add_css_class("qs-window");

        app.add_window(&window);
        window.present();
    });

    app.run_with_args::<&str>(&[]);
}

fn run_dump() {
    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();

    std::thread::Builder::new()
        .name("audio-dump".into())
        .spawn(move || {
            let service = AudioService::new(cmd_rx, cmd_tx, event_tx);
            service.run();
        })
        .ok();

    match event_rx.recv_blocking() {
        Ok(state) => match serde_json::to_string_pretty(&state) {
            Ok(json) => println!("{}", json),
            Err(e) => tracing::error!("Serialización fallida: {:?}", e),
        },
        Err(e) => tracing::error!("Estado no recibido: {:?}", e),
    }
    std::process::exit(0);
}
