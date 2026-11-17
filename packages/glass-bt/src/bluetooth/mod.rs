pub mod agent;

use std::collections::HashSet;
use std::str::FromStr;
use std::sync::Arc;
use std::time::Duration;
use bluer::{Adapter, AdapterEvent, AdapterProperty, Address, DeviceEvent, Session};
use futures_util::{StreamExt, pin_mut};
use tokio::sync::{oneshot, Mutex};
use tokio::time::sleep;

use crate::events::{BtCommand, BtEvent, DeviceInfo, DeviceType};
use self::agent::AgentController;

pub struct BluetoothService {
    cmd_rx: async_channel::Receiver<BtCommand>,
    ui_tx: async_channel::Sender<BtEvent>,
    agent_controller: AgentController,
}

impl BluetoothService {
    pub fn new(
        cmd_rx: async_channel::Receiver<BtCommand>,
        ui_tx: async_channel::Sender<BtEvent>,
    ) -> Self {
        let agent_controller = AgentController::new(ui_tx.clone());
        Self {
            cmd_rx,
            ui_tx,
            agent_controller,
        }
    }

    pub async fn run(self) {
        loop {
            match Session::new().await {
                Ok(session) => {
                    // Register pairing agent
                    let agent = self.agent_controller.build_agent();
                    let _agent_handle = match session.register_agent(agent).await {
                        Ok(h) => Some(h),
                        Err(e) => {
                            eprintln!("Aviso: No se pudo registrar el agente de emparejamiento: {e}");
                            None
                        }
                    };

                    match session.default_adapter().await {
                        Ok(adapter) => {
                            if let Err(e) = self.run_adapter_loop(&adapter).await {
                                eprintln!("Error en loop de adaptador: {e}");
                            }
                        }
                        Err(e) => {
                            let _ = self.ui_tx.send(BtEvent::AdapterStatus {
                                powered: false,
                                discovering: false,
                                name: "Sin Adaptador".into(),
                                address: "".into(),
                            }).await;
                            let _ = self.ui_tx.send(BtEvent::StatusMessage {
                                text: format!("No se encontró adaptador Bluetooth: {e}"),
                                is_error: true,
                            }).await;
                        }
                    }
                }
                Err(e) => {
                    let _ = self.ui_tx.send(BtEvent::StatusMessage {
                        text: format!("Error al conectar con BlueZ (bluetoothd): {e}"),
                        is_error: true,
                    }).await;
                }
            }

            // Retry after brief delay if session dropped or failed
            sleep(Duration::from_secs(3)).await;
        }
    }

    async fn run_adapter_loop(&self, adapter: &Adapter) -> bluer::Result<()> {
        let powered = adapter.is_powered().await.unwrap_or(false);
        let discovering = adapter.is_discovering().await.unwrap_or(false);
        let name = adapter.name().to_string();
        let address = adapter.address().await.map(|a| a.to_string()).unwrap_or_default();

        let _ = self.ui_tx.send(BtEvent::AdapterStatus {
            powered,
            discovering,
            name,
            address,
        }).await;

        // Load existing devices
        let known_devices = adapter.device_addresses().await.unwrap_or_default();
        let monitored_devices = Arc::new(Mutex::new(HashSet::<Address>::new()));

        for addr in known_devices {
            if let Ok(info) = Self::query_device_info(adapter, addr).await {
                let _ = self.ui_tx.send(BtEvent::DeviceAdded(info)).await;
                Self::spawn_device_watcher(adapter.clone(), addr, self.ui_tx.clone(), monitored_devices.clone());
            }
        }

        let adapter_events = adapter.events().await?;
        pin_mut!(adapter_events);

        let mut discovery_cancel: Option<oneshot::Sender<()>> = None;

        loop {
            tokio::select! {
                Some(event) = adapter_events.next() => {
                    match event {
                        AdapterEvent::PropertyChanged(AdapterProperty::Powered(p)) => {
                            let discovering = adapter.is_discovering().await.unwrap_or(false);
                            let _ = self.ui_tx.send(BtEvent::AdapterStatus {
                                powered: p,
                                discovering,
                                name: adapter.name().to_string(),
                                address: adapter.address().await.map(|a| a.to_string()).unwrap_or_default(),
                            }).await;
                        }
                        AdapterEvent::PropertyChanged(AdapterProperty::Discovering(d)) => {
                            let _ = self.ui_tx.send(BtEvent::ScanStateChanged(d)).await;
                        }
                        AdapterEvent::DeviceAdded(addr) => {
                            if let Ok(info) = Self::query_device_info(adapter, addr).await {
                                let _ = self.ui_tx.send(BtEvent::DeviceAdded(info)).await;
                                Self::spawn_device_watcher(adapter.clone(), addr, self.ui_tx.clone(), monitored_devices.clone());
                            }
                        }
                        AdapterEvent::DeviceRemoved(addr) => {
                            let _ = self.ui_tx.send(BtEvent::DeviceRemoved(addr.to_string())).await;
                            monitored_devices.lock().await.remove(&addr);
                        }
                        _ => {}
                    }
                }
                Ok(cmd) = self.cmd_rx.recv() => {
                    match cmd {
                        BtCommand::TogglePower => {
                            let current = adapter.is_powered().await.unwrap_or(false);
                            let new_p = !current;
                            let _ = adapter.set_powered(new_p).await;
                            let discovering = adapter.is_discovering().await.unwrap_or(false);
                            let _ = self.ui_tx.send(BtEvent::AdapterStatus {
                                powered: new_p,
                                discovering,
                                name: adapter.name().to_string(),
                                address: adapter.address().await.map(|a| a.to_string()).unwrap_or_default(),
                            }).await;
                        }
                        BtCommand::SetPower(val) => {
                            let _ = adapter.set_powered(val).await;
                            let discovering = adapter.is_discovering().await.unwrap_or(false);
                            let _ = self.ui_tx.send(BtEvent::AdapterStatus {
                                powered: val,
                                discovering,
                                name: adapter.name().to_string(),
                                address: adapter.address().await.map(|a| a.to_string()).unwrap_or_default(),
                            }).await;
                        }
                        BtCommand::StartScan => {
                            if discovery_cancel.is_none() {
                                match adapter.discover_devices().await {
                                    Ok(mut stream) => {
                                        let (tx, mut rx) = oneshot::channel();
                                        discovery_cancel = Some(tx);
                                        let ui_tx = self.ui_tx.clone();
                                        tokio::spawn(async move {
                                            let _ = ui_tx.send(BtEvent::ScanStateChanged(true)).await;
                                            loop {
                                                tokio::select! {
                                                    _ = &mut rx => break,
                                                    item = stream.next() => {
                                                        if item.is_none() {
                                                            break;
                                                        }
                                                    }
                                                }
                                            }
                                            let _ = ui_tx.send(BtEvent::ScanStateChanged(false)).await;
                                        });
                                    }
                                    Err(e) => {
                                        let _ = self.ui_tx.send(BtEvent::StatusMessage {
                                            text: format!("Error al iniciar escaneo: {e}"),
                                            is_error: true,
                                        }).await;
                                    }
                                }
                            }
                        }
                        BtCommand::StopScan => {
                            if let Some(tx) = discovery_cancel.take() {
                                let _ = tx.send(());
                                let _ = self.ui_tx.send(BtEvent::ScanStateChanged(false)).await;
                            }
                        }
                        BtCommand::ToggleScan => {
                            if let Some(tx) = discovery_cancel.take() {
                                let _ = tx.send(());
                                let _ = self.ui_tx.send(BtEvent::ScanStateChanged(false)).await;
                            } else {
                                match adapter.discover_devices().await {
                                    Ok(mut stream) => {
                                        let (tx, mut rx) = oneshot::channel();
                                        discovery_cancel = Some(tx);
                                        let ui_tx = self.ui_tx.clone();
                                        tokio::spawn(async move {
                                            let _ = ui_tx.send(BtEvent::ScanStateChanged(true)).await;
                                            loop {
                                                tokio::select! {
                                                    _ = &mut rx => break,
                                                    item = stream.next() => {
                                                        if item.is_none() {
                                                            break;
                                                        }
                                                    }
                                                }
                                            }
                                            let _ = ui_tx.send(BtEvent::ScanStateChanged(false)).await;
                                        });
                                    }
                                    Err(_e) => {
                                        let discovering = adapter.is_discovering().await.unwrap_or(false);
                                        let _ = self.ui_tx.send(BtEvent::ScanStateChanged(discovering)).await;
                                    }
                                }
                            }
                        }
                        BtCommand::Connect(mac) => {
                            if let Ok(addr) = Address::from_str(&mac)
                                && let Ok(dev) = adapter.device(addr) {
                                    let ui_tx = self.ui_tx.clone();
                                    let adapter_clone = adapter.clone();
                                    let mac_clone = mac.clone();
                                    tokio::spawn(async move {
                                        match dev.connect().await {
                                            Ok(()) => {
                                                if let Ok(info) = Self::query_device_info(&adapter_clone, addr).await {
                                                    let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                                                }
                                                let _ = ui_tx.send(BtEvent::StatusMessage {
                                                    text: format!("Conectado a {}", mac_clone),
                                                    is_error: false,
                                                }).await;
                                            }
                                            Err(e) => {
                                                if let Ok(info) = Self::query_device_info(&adapter_clone, addr).await {
                                                    let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                                                }
                                                let _ = ui_tx.send(BtEvent::StatusMessage {
                                                    text: format!("Error al conectar con {}: {e}", mac_clone),
                                                    is_error: true,
                                                }).await;
                                            }
                                        }
                                    });
                                }
                        }
                        BtCommand::Disconnect(mac) => {
                            if let Ok(addr) = Address::from_str(&mac)
                                && let Ok(dev) = adapter.device(addr) {
                                    let ui_tx = self.ui_tx.clone();
                                    let adapter_clone = adapter.clone();
                                    let mac_clone = mac.clone();
                                    tokio::spawn(async move {
                                        let _ = dev.disconnect().await;
                                        if let Ok(info) = Self::query_device_info(&adapter_clone, addr).await {
                                            let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                                        }
                                        let _ = ui_tx.send(BtEvent::StatusMessage {
                                            text: format!("Desconectado de {}", mac_clone),
                                            is_error: false,
                                        }).await;
                                    });
                                }
                        }
                        BtCommand::Pair(mac) => {
                            if let Ok(addr) = Address::from_str(&mac)
                                && let Ok(dev) = adapter.device(addr) {
                                    let ui_tx = self.ui_tx.clone();
                                    let adapter_clone = adapter.clone();
                                    let mac_clone = mac.clone();
                                    tokio::spawn(async move {
                                        match dev.pair().await {
                                            Ok(()) => {
                                                let _ = dev.set_trusted(true).await;
                                                let _ = dev.connect().await;
                                                if let Ok(info) = Self::query_device_info(&adapter_clone, addr).await {
                                                    let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                                                }
                                                let _ = ui_tx.send(BtEvent::StatusMessage {
                                                    text: format!("Emparejado exitosamente con {}", mac_clone),
                                                    is_error: false,
                                                }).await;
                                            }
                                            Err(e) => {
                                                if let Ok(info) = Self::query_device_info(&adapter_clone, addr).await {
                                                    let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                                                }
                                                let _ = ui_tx.send(BtEvent::StatusMessage {
                                                    text: format!("Error al emparejar con {}: {e}", mac_clone),
                                                    is_error: true,
                                                }).await;
                                            }
                                        }
                                    });
                                }
                        }
                        BtCommand::Forget(mac) => {
                            if let Ok(addr) = Address::from_str(&mac) {
                                match adapter.remove_device(addr).await {
                                    Ok(()) => {
                                        let _ = self.ui_tx.send(BtEvent::DeviceRemoved(mac)).await;
                                    }
                                    Err(e) => {
                                        let _ = self.ui_tx.send(BtEvent::StatusMessage {
                                            text: format!("Error al olvidar dispositivo: {e}"),
                                            is_error: true,
                                        }).await;
                                    }
                                }
                            }
                        }
                        BtCommand::SetTrusted(mac, val) => {
                            if let Ok(addr) = Address::from_str(&mac)
                                && let Ok(dev) = adapter.device(addr) {
                                    let _ = dev.set_trusted(val).await;
                                }
                        }
                        BtCommand::PairingResponse { req_id, accept, pin_code } => {
                            self.agent_controller.handle_response(req_id, accept, pin_code).await;
                        }
                    }
                }
                else => break,
            }
        }

        Ok(())
    }

    async fn query_device_info(adapter: &Adapter, addr: Address) -> bluer::Result<DeviceInfo> {
        let dev = adapter.device(addr)?;
        let name = dev.name().await?.unwrap_or_else(|| addr.to_string());
        let alias = dev.alias().await.ok();
        let icon_str = dev.icon().await.ok().flatten();
        let device_type = DeviceType::from_icon_and_name(icon_str.as_deref(), &name);
        let paired = dev.is_paired().await.unwrap_or(false);
        let connected = dev.is_connected().await.unwrap_or(false);
        let trusted = dev.is_trusted().await.unwrap_or(false);
        let battery_percentage = dev.battery_percentage().await.ok().flatten();
        let rssi = dev.rssi().await.ok().flatten();

        Ok(DeviceInfo {
            mac: addr.to_string(),
            name,
            alias,
            device_type,
            paired,
            connected,
            trusted,
            battery_percentage,
            rssi,
        })
    }

    fn spawn_device_watcher(
        adapter: Adapter,
        addr: Address,
        ui_tx: async_channel::Sender<BtEvent>,
        monitored: Arc<Mutex<HashSet<Address>>>,
    ) {
        tokio::spawn(async move {
            {
                let mut set = monitored.lock().await;
                if set.contains(&addr) {
                    return;
                }
                set.insert(addr);
            }

            if let Ok(dev) = adapter.device(addr)
                && let Ok(events) = dev.events().await {
                    pin_mut!(events);
                    while let Some(event) = events.next().await {
                        let DeviceEvent::PropertyChanged(_) = event;
                        if let Ok(info) = Self::query_device_info(&adapter, addr).await {
                            let _ = ui_tx.send(BtEvent::DeviceUpdated(info)).await;
                        }
                    }
                }
        });
    }
}
