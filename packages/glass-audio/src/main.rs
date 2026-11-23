//! glass-audio: mezclador GTK4 estilo One UI 8.5 con barras de relleno,
//! cristal translúcido y colores dinámicos del wallpaper (Matugen/Wallust).

use audio_core::{AudioCommand, AudioService, AudioState};
use async_channel::unbounded;
use gtk4::prelude::*;
use gtk4::{Application, ApplicationWindow, CssProvider, gdk};
use std::{
    cell::{Cell, RefCell},
    collections::{HashMap, HashSet},
    rc::Rc,
};

mod ui;

#[derive(Clone)]
pub struct MixerState {
    pub audio: Rc<RefCell<AudioState>>,
    pub commands: Rc<async_channel::Sender<AudioCommand>>,
    /// Objetivos con volumen por canal independiente.
    pub unlocked: Rc<RefCell<HashSet<String>>>,
    /// Pestaña visible (nombre interno), para el filtro "Mostrar:".
    pub current_tab: Rc<RefCell<String>>,
    /// Filtro elegido en cada pestaña.
    pub filters: Rc<RefCell<HashMap<String, usize>>>,
    /// `true` mientras el usuario arrastra una barra: evita reconstruir la UI.
    pub dragging: Rc<Cell<bool>>,
    /// Clave del objetivo que se está arrastrando (para no sobrescribirlo).
    pub dragging_target: Rc<RefCell<Option<String>>>,
    /// Barra que debe recuperar el foco tras el refresco (accesibilidad).
    pub focus_target: Rc<RefCell<Option<String>>>,
    /// Casillas de Configuración.
    pub show_meters: Rc<Cell<bool>>,
    pub hide_unavailable: Rc<Cell<bool>>,
}

impl MixerState {
    fn send(&self, command: AudioCommand) {
        let _ = self.commands.send_blocking(command);
    }

    /// Filtro seleccionado en una pestaña (0 por defecto).
    pub fn filter_index(&self, tab: &str) -> usize {
        *self.filters.borrow().get(tab).unwrap_or(&0)
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
        current_tab: Rc::new(RefCell::new("playback".into())),
        filters: Rc::new(RefCell::new(HashMap::new())),
        dragging: Rc::new(Cell::new(false)),
        dragging_target: Rc::new(RefCell::new(None)),
        focus_target: Rc::new(RefCell::new(None)),
        show_meters: Rc::new(Cell::new(true)),
        hide_unavailable: Rc::new(Cell::new(false)),
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
            .default_width(560)
            .default_height(720)
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
