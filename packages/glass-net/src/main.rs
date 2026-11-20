pub mod events;
pub mod network;
pub mod ui;

use std::env;
use std::thread;
use events::{NetCommand, NetEvent};
use network::NetworkService;
use ui::UiApp;

fn main() {
    let use_layer = env::args().any(|a| a == "--layer");
    // --hidden: precarga como daemon sin mostrar la ventana (autostart)
    let start_hidden = env::args().any(|a| a == "--hidden");

    // Canales bidireccionales Tokio <-> GTK4
    let (cmd_tx, cmd_rx) = async_channel::unbounded::<NetCommand>();
    let (event_tx, event_rx) = async_channel::unbounded::<NetEvent>();

    // Hilo dedicado para el runtime asíncrono de Tokio (NetworkManager / zbus)
    let net_handle = thread::Builder::new()
        .name("network-worker".into())
        .spawn(move || {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("Fallo al inicializar el runtime de Tokio");

            rt.block_on(async move {
                let service = NetworkService::new(cmd_rx, event_tx);
                service.run().await;
            });
        })
        .expect("Fallo al crear hilo del worker de red");

    // Interfaz gráfica GTK4 en el hilo principal (flotante por defecto)
    let ui_app = UiApp::new(cmd_tx, event_rx, use_layer, start_hidden);
    ui_app.run();

    // Al cerrar la ventana, terminar limpiamente
    drop(net_handle);
}
