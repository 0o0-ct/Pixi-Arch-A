//! # glass-audio
//!
//! Control de volumen para Arch + Hyprland (clon de pavucontrol).
//! Hereda el sistema de diseño de glass-bt (One UI 8+ / glass).

mod ui;

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use async_channel::unbounded;
use audio_core::{AudioCommand, AudioService, AudioState};
use gtk4::prelude::*;
use gtk4::Application;
use glass_theme::init_theme;

fn main() {
    // Los logs van a stderr (para no ensuciar la salida JSON de --dump).
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_env_filter(filter)
        .try_init();

    let args: Vec<String> = std::env::args().collect();

    // Modo dump: imprime el estado de audio como JSON (para diagnóstico).
    if args.iter().any(|a| a == "--dump") {
        run_dump();
        return;
    }

    // Análisis de pestaña: --tab=output|input|playback|record|config
    let tab = args
        .iter()
        .position(|a| a == "--tab")
        .and_then(|i| args.get(i + 1))
        .cloned();
    let expand = args.iter().any(|a| a == "--expand");

    let app = Application::builder()
        .application_id("com.pixi.glassaudio")
        .build();

    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();

    // Hilo dedicado para el servicio de audio (bloqueante, event-driven).
    let ping_tx = cmd_tx.clone();
    let spawned = std::thread::Builder::new()
        .name("audio-worker".into())
        .spawn(move || {
            let service = AudioService::new(cmd_rx, ping_tx, event_tx);
            service.run();
        });
    if let Err(e) = spawned {
        tracing::error!("No se pudo crear el hilo del servicio de audio: {e:?}");
    }

    let window_slot: Rc<RefCell<Option<Rc<RefCell<ui::AudioWindow>>>>> =
        Rc::new(RefCell::new(None));
    let initial_tab = Rc::new(RefCell::new(tab));
    let initial_expand = Rc::new(Cell::new(expand));

    app.connect_startup(move |_| {
        let _ = init_theme();
    });

    let cmd_tx_activate = cmd_tx.clone();
    let event_rx_activate = event_rx;
    let window_slot_activate = window_slot;
    let initial_tab_activate = initial_tab;
    let initial_expand_activate = initial_expand;

    app.connect_activate(move |app| {
        let slot = window_slot_activate.clone();

        // Instancia única: si la ventana ya existe, solo presentarla.
        if let Some(win) = slot.borrow().clone() {
            let tab = initial_tab_activate.borrow_mut().take();
            win.borrow().select_tab(tab.as_deref());
            win.borrow().window.present();
            let _ = cmd_tx_activate.send_blocking(AudioCommand::Subscribe);
            return;
        }

        let tab = initial_tab_activate.borrow_mut().take();
        let expand = initial_expand_activate.get();
        let audio_window = Rc::new(RefCell::new(ui::AudioWindow::new(
            app,
            cmd_tx_activate.clone(),
            event_rx_activate.clone(),
            tab.as_deref(),
            expand,
        )));
        *slot.borrow_mut() = Some(audio_window.clone());
        audio_window.borrow().window.present();
    });

    // argv vacío: GTK no debe re-parsear nuestras opciones propias
    // (`--tab`, `--expand`, `--dump`), si no aborta con "opción desconocida".
    app.run_with_args::<&str>(&[]);
}

/// Modo `--dump`: conecta a PulseAudio e imprime el estado como JSON.
fn run_dump() {
    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (ping_tx, ping_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();

    let spawned = std::thread::Builder::new()
        .name("audio-dump".into())
        .spawn(move || {
            let service = AudioService::new(cmd_rx, ping_tx, event_tx);
            service.run();
        });
    if let Err(e) = spawned {
        tracing::error!("No se pudo crear el hilo del servicio de audio: {e:?}");
        return;
    }

    // Recibir el primer estado completo.
    match event_rx.recv_blocking() {
        Ok(state) => match serde_json::to_string_pretty(&state) {
            Ok(json) => println!("{json}"),
            Err(e) => tracing::error!("No se pudo serializar el estado: {e:?}"),
        },
        Err(e) => tracing::error!("No llegó el estado del servicio: {e:?}"),
    }

    // El servicio no termina solo (retiene su propio sender); salir directamente.
    drop(cmd_tx);
    drop(ping_rx);
    std::process::exit(0);
}
