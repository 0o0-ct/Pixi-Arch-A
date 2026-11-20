//! # glass-audio
//!
//! Control de volumen para Arch + Hyprland (clon de pavucontrol).
//! Hereda el sistema de diseño de glass-bt (One UI 8+ / glass).

mod ui;

use std::env;
use std::rc::Rc;
use std::cell::RefCell;
use async_channel::{unbounded, Sender, Receiver};
use audio_core::{AudioCommand, AudioState, AudioService};
use gtk4::gio;
use gtk4::gio::prelude::*;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{Application, CssProvider};
use glass_theme::init_theme;

fn main() {
    let app = Application::builder()
        .application_id("com.pixi.glass-audio")
        .build();

    let (cmd_tx, cmd_rx) = unbounded::<AudioCommand>();
    let (event_tx, event_rx) = unbounded::<AudioState>();

    // Hilo dedicado para el servicio de audio
    let _audio_handle = std::thread::Builder::new()
        .name("audio-worker".into())
        .spawn(move || {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("Fallo al inicializar runtime de Tokio");
            rt.block_on(async move {
                let service = AudioService::new(cmd_rx, event_tx);
                service.run().await;
            });
        })
        .expect("Fallo al crear hilo del worker de audio");

    let window_slot: Rc<RefCell<Option<Rc<RefCell<ui::AudioWindow>>>>> =
        Rc::new(RefCell::new(None));

    app.connect_startup(move |_| {
        let _ = glass_theme::init_theme();
    });

    let cmd_tx_clone = cmd_tx.clone();
    let event_rx_clone = event_rx.clone();
    let window_slot_clone = window_slot.clone();

    app.connect_activate(move |app| {
        let slot = window_slot_clone.clone();

        // Si la ventana ya existe, solo mostrarla
        if let Some(win) = slot.borrow().clone() {
            win.borrow().window.present();
            let _ = cmd_tx_clone.send_blocking(AudioCommand::Subscribe);
            return;
        }

        let audio_window = Rc::new(RefCell::new(ui::AudioWindow::new(
            app,
            cmd_tx_clone.clone(),
            event_rx_clone.clone(),
        )));
        *slot.borrow_mut() = Some(audio_window.clone());

        audio_window.borrow().window.present();
    });

    app.run();
}