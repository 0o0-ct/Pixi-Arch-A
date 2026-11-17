pub mod events;
pub mod bluetooth;
pub mod ui;

use std::env;
use std::thread;
use events::{BtCommand, BtEvent};
use bluetooth::BluetoothService;
use ui::UiApp;

fn main() {
    let use_layer = env::args().any(|a| a == "--layer");

    // Canales bidireccionales Tokio <-> GTK4
    let (cmd_tx, cmd_rx) = async_channel::unbounded::<BtCommand>();
    let (event_tx, event_rx) = async_channel::unbounded::<BtEvent>();

    // Hilo dedicado para el runtime asíncrono de Tokio (BlueZ / bluer)
    let bt_handle = thread::Builder::new()
        .name("bluetooth-worker".into())
        .spawn(move || {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("Fallo al inicializar el runtime de Tokio");

            rt.block_on(async move {
                let service = BluetoothService::new(cmd_rx, event_tx);
                service.run().await;
            });
        })
        .expect("Fallo al crear hilo del worker Bluetooth");

    // Interfaz gráfica GTK4 en el hilo principal (flotante por defecto)
    let ui_app = UiApp::new(cmd_tx, event_rx, use_layer);
    ui_app.run();

    // Al cerrar la ventana, terminar limpiamente
    drop(bt_handle);
}
