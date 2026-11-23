//! glass-audio: mezclador de audio GTK4 con diseño inspirado en One UI y colores
//! dinámicos del wallpaper (Matugen/Wallust).

use audio_core::{AudioCommand, AudioService, AudioState};
use async_channel::unbounded;
use gtk4::prelude::*;
use gtk4::{Application, ApplicationWindow, CssProvider, gdk};
use std::{cell::{Cell, RefCell}, collections::HashSet, rc::Rc};

mod ui;

#[derive(Clone)]
pub struct MixerState {
    pub audio: Rc<RefCell<AudioState>>,
    pub commands: Rc<async_channel::Sender<AudioCommand>>,
    /// Targets cuyo volumen por canal se modifica de forma independiente.
    pub unlocked: Rc<RefCell<HashSet<String>>>,
    pub show_all: Rc<Cell<bool>>,
}

impl MixerState {
    fn send(&self, command: AudioCommand) {
        let _ = self.commands.send_blocking(command);
    }
}

fn install_app_css() {
    let provider = CssProvider::new();
    provider.load_from_data(include_str!("ui.css"));
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION + 1,
        );
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|arg| arg == "--dump") {
        run_dump();
        return;
    }

    let _ = tracing_subscriber::fmt().with_writer(std::io::stderr).try_init();
    gtk4::init().expect("No se pudo inicializar GTK4");
    glass_theme::init_theme();
    install_app_css();

    let app = Application::builder()
        .application_id("com.pixi.glassaudio")
        .build();

    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();
    let audio_commands = cmd_tx.clone();
    std::thread::Builder::new()
        .name("glass-audio-service".into())
        .spawn(move || AudioService::new(cmd_rx, audio_commands, event_tx).run())
        .expect("No se pudo iniciar el servicio de audio");

    let state = MixerState {
        audio: Rc::new(RefCell::new(AudioState::default())),
        commands: Rc::new(cmd_tx),
        unlocked: Rc::new(RefCell::new(HashSet::new())),
        show_all: Rc::new(Cell::new(true)),
    };
    let state_app = state.clone();
    let events_for_ui = Rc::new(RefCell::new(None::<Box<dyn Fn()>>));
    let refresh_for_events = events_for_ui.clone();
    glib::spawn_future_local(async move {
        while let Ok(audio) = event_rx.recv().await {
            *state_app.audio.borrow_mut() = audio;
            if let Some(refresh) = refresh_for_events.borrow().as_ref() {
                refresh();
            }
        }
    });

    let state_activate = state.clone();
    let refresh_slot = events_for_ui.clone();
    app.connect_activate(move |app| {
        let window = ApplicationWindow::builder()
            .application(app)
            .title("Sonido")
            .default_width(1040)
            .default_height(820)
            .resizable(true)
            .build();
        window.add_css_class("audio-window");
        let (panel, refresh) = ui::build_mixer(state_activate.clone(), window.clone());
        *refresh_slot.borrow_mut() = Some(Box::new(refresh));
        window.set_child(Some(&panel));
        window.present();
    });
    app.run_with_args::<&str>(&[]);
}

fn run_dump() {
    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();
    let ping = cmd_tx.clone();
    let _ = std::thread::Builder::new()
        .name("audio-dump-service".into())
        .spawn(move || AudioService::new(cmd_rx, ping, event_tx).run());
    match event_rx.recv_blocking() {
        Ok(state) => match serde_json::to_string_pretty(&state) {
            Ok(json) => println!("{json}"),
            Err(error) => eprintln!("No se pudo serializar el estado: {error}"),
        },
        Err(error) => eprintln!("No se recibió el estado de audio: {error}"),
    }
}
