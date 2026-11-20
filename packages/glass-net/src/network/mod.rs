//! Backend de glass-net: hablamos directamente con NetworkManager por D-Bus
//! (org.freedesktop.NetworkManager) usando zbus, con el mismo patrón que
//! glass-bt: hilo Tokio dedicado + canales async_channel hacia GTK4.
//!
//! Estrategia de refresco: bucle select! con un ticker de 2s que difunde
//! cambios (NmStatus / WifiDevice / EthernetState / ApAdded / ApUpdated /
//! ApRemoved / KnownSsids / Vpns) solo cuando algo cambió, más streams de
//! propiedades D-Bus para reaccionar al instante, y escaneos periódicos cada
//! ~12s. Cada operación de conexión corre en su propio tokio::spawn.

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use futures_util::StreamExt;
use tokio::sync::Mutex;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};
use zbus::{proxy, Connection, Proxy};

use crate::events::{ApInfo, EthernetInfo, NetCommand, NetEvent, VpnInfo, WifiDeviceInfo};

// ── Constantes NM ────────────────────────────────────────────────────────────
const NM_SERVICE: &str = "org.freedesktop.NetworkManager";
const DEVICE_TYPE_ETHERNET: u32 = 1;
const DEVICE_TYPE_WIFI: u32 = 2;

// NM_802_11_AP_SEC (RsnFlags / WpaFlags)
const AP_SEC_KEY_MGMT_PSK: u32 = 0x100;
const AP_SEC_KEY_MGMT_SAE: u32 = 0x400;
// NM_802_11_AP_FLAGS
const AP_FLAGS_PRIVACY: u32 = 0x1;

// ── Proxies D-Bus (macros de zbus) ───────────────────────────────────────────

#[proxy(
    interface = "org.freedesktop.NetworkManager",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
trait NetworkManager {
    fn get_all_devices(&self) -> zbus::Result<Vec<OwnedObjectPath>>;

    fn activate_connection(
        &self,
        connection: OwnedObjectPath,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> zbus::Result<OwnedObjectPath>;

    fn add_and_activate_connection(
        &self,
        connection: HashMap<String, HashMap<String, OwnedValue>>,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;

    fn deactivate_connection(&self, active_connection: OwnedObjectPath) -> zbus::Result<()>;

    #[zbus(property)]
    fn wireless_enabled(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_wireless_enabled(&self, value: bool) -> zbus::Result<()>;
    #[zbus(property)]
    fn networking_enabled(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn active_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device",
    default_service = "org.freedesktop.NetworkManager"
)]
trait Device {
    #[zbus(property)]
    fn device_type(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn state(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn interface(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn ip4_config(&self) -> zbus::Result<OwnedObjectPath>;
    fn disconnect(&self) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device.Wireless",
    default_service = "org.freedesktop.NetworkManager"
)]
trait WirelessDevice {
    fn get_access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
    fn request_scan(&self, options: HashMap<String, OwnedValue>) -> zbus::Result<()>;
    #[zbus(property)]
    fn active_access_point(&self) -> zbus::Result<OwnedObjectPath>;
    #[zbus(property)]
    fn last_scan(&self) -> zbus::Result<u64>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.AccessPoint",
    default_service = "org.freedesktop.NetworkManager"
)]
trait AccessPoint {
    #[zbus(property)]
    fn ssid(&self) -> zbus::Result<Vec<u8>>;
    #[zbus(property)]
    fn strength(&self) -> zbus::Result<u8>;
    #[zbus(property)]
    fn flags(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn wpa_flags(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn rsn_flags(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn frequency(&self) -> zbus::Result<u32>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Settings",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/Settings"
)]
trait Settings {
    fn list_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Settings.Connection",
    default_service = "org.freedesktop.NetworkManager"
)]
trait SettingsConnection {
    fn get_settings(&self) -> zbus::Result<HashMap<String, HashMap<String, OwnedValue>>>;
    fn delete(&self) -> zbus::Result<()>;
}

// ── Estado interno ───────────────────────────────────────────────────────────

/// Conexión Wi-Fi pendiente de recibir credenciales del diálogo de contraseña
struct PendingConnect {
    ap_path: String,
    device_path: String,
    ssid: String,
    ssid_bytes: Vec<u8>,
    key_mgmt: &'static str,
}

/// Último estado difundido a la UI, para no reenviar eventos idénticos
#[derive(Default)]
struct DiffState {
    last_nm: Option<(bool, bool)>,
    last_wifi: Option<WifiDeviceInfo>,
    last_eth: Option<EthernetInfo>,
    aps: HashMap<String, ApInfo>,
    last_known: Option<HashSet<String>>,
    last_vpns: Option<Vec<VpnInfo>>,
    scan_started: Option<(u64, Instant)>, // last_scan antes de escanear + instante
    /// ¿Ventana visible? Oculta (modo daemon) → sin escaneos ni refresco periódico
    visible: bool,
}

pub struct NetworkService {
    cmd_rx: async_channel::Receiver<NetCommand>,
    ui_tx: async_channel::Sender<NetEvent>,
    pending: Arc<Mutex<HashMap<u64, PendingConnect>>>,
    req_counter: Arc<AtomicU64>,
    refresh_notify: Arc<tokio::sync::Notify>,
}

impl NetworkService {
    pub fn new(
        cmd_rx: async_channel::Receiver<NetCommand>,
        ui_tx: async_channel::Sender<NetEvent>,
    ) -> Self {
        Self {
            cmd_rx,
            ui_tx,
            pending: Arc::new(Mutex::new(HashMap::new())),
            req_counter: Arc::new(AtomicU64::new(1)),
            refresh_notify: Arc::new(tokio::sync::Notify::new()),
        }
    }

    pub async fn run(self) {
        loop {
            match Connection::system().await {
                Ok(conn) => {
                    if let Err(e) = self.run_nm_loop(&conn).await {
                        eprintln!("Error en loop de NetworkManager: {e}");
                        let _ = self.ui_tx.send(NetEvent::StatusMessage {
                            text: format!("Error de conexión con NetworkManager: {e}"),
                            is_error: true,
                        }).await;
                    }
                }
                Err(e) => {
                    let _ = self.ui_tx.send(NetEvent::StatusMessage {
                        text: format!("No se pudo conectar al bus de sistema (NetworkManager): {e}"),
                        is_error: true,
                    }).await;
                }
            }
            // Reintentar tras un fallo de sesión
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
    }

    async fn run_nm_loop(&self, conn: &Connection) -> zbus::Result<()> {
        let nm = NetworkManagerProxy::builder(conn).build().await?;
        let settings = SettingsProxy::builder(conn).build().await?;
        let mut state = DiffState::default();

        // Estado inicial inmediato + escaneo inicial
        self.refresh(conn, &nm, &settings, &mut state, true).await;
        self.start_scan(conn, &mut state).await;

        // Streams de propiedades para reaccionar en caliente
        let mut nm_wifi_stream = nm.receive_wireless_enabled_changed().await;
        let mut nm_actives_stream = nm.receive_active_connections_changed().await;

        let mut ticker = tokio::time::interval(Duration::from_millis(2000));
        ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
        let mut cycle: u32 = 0;

        loop {
            tokio::select! {
                _ = ticker.tick() => {
                    cycle = cycle.wrapping_add(1);
                    // Modo daemon oculto: sin escaneos ni refresco periódico (cero consumo)
                    if !state.visible {
                        continue;
                    }
                    // ¿Terminó el escaneo en curso? (LastScan avanza o timeout)
                    self.check_scan_finished(conn, &mut state).await;
                    // Escaneo periódico cada 6 ciclos (~12s)
                    if cycle.is_multiple_of(6) && state.scan_started.is_none() {
                        let wifi_on = state.last_nm.map(|(w, _)| w).unwrap_or(false);
                        if wifi_on && state.last_wifi.as_ref().map(|w| w.present).unwrap_or(false) {
                            self.start_scan(conn, &mut state).await;
                        }
                    }
                    // Perfiles/VPN (más caro) cada 3 ciclos (~6s)
                    self.refresh(conn, &nm, &settings, &mut state, cycle.is_multiple_of(3)).await;
                }
                Some(_enabled) = nm_wifi_stream.next() => {
                    self.refresh(conn, &nm, &settings, &mut state, false).await;
                }
                Some(_actives) = nm_actives_stream.next() => {
                    self.refresh(conn, &nm, &settings, &mut state, false).await;
                }
                Ok(cmd) = self.cmd_rx.recv() => {
                    self.handle_command(cmd, conn, &nm, &settings, &mut state).await;
                }
                _ = self.refresh_notify.notified() => {
                    // Refresco inmediato tras cualquier operación lanzada por un comando
                    self.refresh(conn, &nm, &settings, &mut state, true).await;
                }
                else => break,
            }
        }

        Ok(())
    }

    // ── Refresco completo con difusión de diferencias ────────────────────────

    async fn refresh(
        &self,
        conn: &Connection,
        nm: &NetworkManagerProxy<'_>,
        settings: &SettingsProxy<'_>,
        state: &mut DiffState,
        include_settings: bool,
    ) {
        // 1. Radios NM
        let wifi_enabled = nm.wireless_enabled().await.unwrap_or(false);
        let networking_enabled = nm.networking_enabled().await.unwrap_or(true);
        let nm_tuple = (wifi_enabled, networking_enabled);
        if state.last_nm.as_ref() != Some(&nm_tuple) {
            state.last_nm = Some(nm_tuple);
            let _ = self.ui_tx.send(NetEvent::NmStatus { wifi_enabled, networking_enabled }).await;
        }

        // 2. Dispositivos (primer Wi-Fi y primer Ethernet)
        let mut wifi_dev: Option<(OwnedObjectPath, u32, String)> = None;
        let mut eth_dev: Option<(OwnedObjectPath, u32, String)> = None;

        let devices = nm.get_all_devices().await.unwrap_or_default();
        for path in &devices {
            let Ok(dev) = build_device_proxy(conn, path).await else { continue };
            let Ok(dtype) = dev.device_type().await else { continue };
            if dtype == DEVICE_TYPE_WIFI && wifi_dev.is_none() {
                let st = dev.state().await.unwrap_or(0);
                let iface = dev.interface().await.unwrap_or_default();
                wifi_dev = Some((path.clone(), st, iface));
            } else if dtype == DEVICE_TYPE_ETHERNET && eth_dev.is_none() {
                let st = dev.state().await.unwrap_or(0);
                let iface = dev.interface().await.unwrap_or_default();
                eth_dev = Some((path.clone(), st, iface));
            }
            if wifi_dev.is_some() && eth_dev.is_some() {
                break;
            }
        }

        // 3. Estado del dispositivo Wi-Fi
        let wifi_info = if let Some((path, dev_state, iface)) = wifi_dev {
            let wproxy = build_wireless_proxy(conn, &path).await.ok();
            let connected_ssid = if let Some(w) = &wproxy {
                match w.active_access_point().await {
                    Ok(ap) if ap.as_str() != "/" => query_ap(conn, &ap).await.map(|i| i.ssid),
                    _ => None,
                }
            } else {
                None
            };
            let ip = device_ip(conn, &path).await;
            let activating = (40..=90).contains(&dev_state);
            WifiDeviceInfo {
                present: true,
                device_path: path.to_string(),
                interface: iface,
                connected_ssid,
                ip,
                activating,
            }
        } else {
            WifiDeviceInfo {
                present: false,
                device_path: String::new(),
                interface: String::new(),
                connected_ssid: None,
                ip: None,
                activating: false,
            }
        };
        if state.last_wifi.as_ref() != Some(&wifi_info) {
            state.last_wifi = Some(wifi_info.clone());
            let _ = self.ui_tx.send(NetEvent::WifiDevice(wifi_info.clone())).await;
        }

        // 4. Estado Ethernet
        let eth_info = if let Some((path, dev_state, iface)) = eth_dev {
            let ip = device_ip(conn, &path).await;
            EthernetInfo {
                device_path: path.to_string(),
                interface: iface,
                state: dev_state,
                ip,
            }
        } else {
            EthernetInfo {
                device_path: String::new(),
                interface: String::new(),
                state: 0,
                ip: None,
            }
        };
        if state.last_eth.as_ref() != Some(&eth_info) {
            state.last_eth = Some(eth_info.clone());
            let _ = self.ui_tx.send(NetEvent::EthernetState(eth_info)).await;
        }

        // 5. Puntos de acceso Wi-Fi (solo si hay dispositivo; NM lista vacío si está apagado)
        if wifi_info.present {
            let mut seen: HashSet<String> = HashSet::new();
            if let Ok(w) = build_wireless_proxy(conn, &wifi_info.device_path).await
                && let Ok(paths) = w.get_access_points().await {
                    for p in paths {
                        let key = p.to_string();
                        if let Some(info) = query_ap(conn, &p).await {
                            seen.insert(key.clone());
                            match state.aps.get(&key) {
                                Some(old) if *old == info => {}
                                Some(_) => {
                                    state.aps.insert(key, info.clone());
                                    let _ = self.ui_tx.send(NetEvent::ApUpdated(info)).await;
                                }
                                None => {
                                    state.aps.insert(key, info.clone());
                                    let _ = self.ui_tx.send(NetEvent::ApAdded(info)).await;
                                }
                            }
                        }
                    }
                }
            let gone: Vec<String> = state
                .aps
                .keys()
                .filter(|k| !seen.contains(*k))
                .cloned()
                .collect();
            for k in gone {
                state.aps.remove(&k);
                let _ = self.ui_tx.send(NetEvent::ApRemoved(k)).await;
            }
        } else if !state.aps.is_empty() {
            let keys: Vec<String> = state.aps.keys().cloned().collect();
            for k in keys {
                state.aps.remove(&k);
                let _ = self.ui_tx.send(NetEvent::ApRemoved(k)).await;
            }
        }

        // 6. Perfiles conocidos + VPN (más costoso, solo a veces)
        if include_settings {
            self.refresh_profiles(conn, nm, settings, state).await;
        }
    }

    async fn refresh_profiles(
        &self,
        conn: &Connection,
        nm: &NetworkManagerProxy<'_>,
        _settings: &SettingsProxy<'_>,
        state: &mut DiffState,
    ) {
        let settings = match SettingsProxy::builder(conn).build().await {
            Ok(s) => s,
            Err(_) => return,
        };
        let mut known: HashSet<String> = HashSet::new();
        let mut vpns: Vec<VpnInfo> = Vec::new();

        if let Ok(conns) = settings.list_connections().await {
            for cpath in conns {
                let Ok(cproxy) = build_connection_proxy(conn, &cpath).await else { continue };
                let Ok(all) = cproxy.get_settings().await else { continue };
                let section = all.get("connection");

                // SSID Wi-Fi con perfil guardado
                if let Some(bytes) = all
                    .get("802-11-wireless")
                    .and_then(|w| w.get("ssid"))
                    .and_then(value_bytes)
                {
                    known.insert(ssid_string(&bytes));
                }

                // Perfiles VPN
                let ctype = section
                    .and_then(|c| c.get("type"))
                    .and_then(value_str)
                    .unwrap_or_default();
                if ctype == "vpn" {
                    let uuid = section
                        .and_then(|c| c.get("uuid"))
                        .and_then(value_str)
                        .unwrap_or_default();
                    let name = section
                        .and_then(|c| c.get("id"))
                        .and_then(value_str)
                        .unwrap_or_else(|| "VPN".into());
                    if !uuid.is_empty() {
                        vpns.push(VpnInfo {
                            uuid,
                            name,
                            active: false,
                            active_path: String::new(),
                        });
                    }
                }
            }
        }

        // VPN activas (ActiveConnections con Type == "vpn")
        if let Ok(actives) = nm.active_connections().await {
            for apath in actives {
                let Ok(aproxy) = Proxy::new(
                    conn,
                    NM_SERVICE,
                    apath.clone(),
                    "org.freedesktop.NetworkManager.Connection.Active",
                ).await else { continue };
                let ty: Option<String> = aproxy.get_property("Type").await.ok();
                if ty.as_deref() != Some("vpn") {
                    continue;
                }
                let mut marked = false;
                if let Ok(cp) = aproxy.get_property::<OwnedObjectPath>("Connection").await
                    && let Ok(cproxy) = build_connection_proxy(conn, &cp).await
                        && let Ok(all) = cproxy.get_settings().await {
                            let sec = all.get("connection");
                            let uuid = sec
                                .and_then(|c| c.get("uuid"))
                                .and_then(value_str)
                                .unwrap_or_default();
                            let name = sec
                                .and_then(|c| c.get("id"))
                                .and_then(value_str)
                                .unwrap_or_else(|| "VPN".into());
                            if let Some(v) = vpns.iter_mut().find(|v| v.uuid == uuid) {
                                v.active = true;
                                v.active_path = apath.to_string();
                                marked = true;
                            } else {
                                vpns.push(VpnInfo {
                                    uuid,
                                    name,
                                    active: true,
                                    active_path: apath.to_string(),
                                });
                                marked = true;
                            }
                        }
                if !marked {
                    let id: Option<String> = aproxy.get_property("Id").await.ok();
                    vpns.push(VpnInfo {
                        uuid: String::new(),
                        name: id.unwrap_or_else(|| "VPN".into()),
                        active: true,
                        active_path: apath.to_string(),
                    });
                }
            }
        }

        vpns.sort_by(|a, b| {
            b.active
                .cmp(&a.active)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });

        if state.last_known.as_ref() != Some(&known) {
            state.last_known = Some(known.clone());
            let mut list: Vec<String> = known.into_iter().collect();
            list.sort();
            let _ = self.ui_tx.send(NetEvent::KnownSsids(list)).await;
        }
        if state.last_vpns.as_ref() != Some(&vpns) {
            state.last_vpns = Some(vpns.clone());
            let _ = self.ui_tx.send(NetEvent::Vpns(vpns)).await;
        }
    }

    // ── Escaneo ──────────────────────────────────────────────────────────────

    async fn start_scan(&self, conn: &Connection, state: &mut DiffState) {
        let Some(wifi) = state.last_wifi.clone() else { return };
        if !wifi.present || wifi.device_path.is_empty() {
            return;
        }
        let Ok(w) = build_wireless_proxy(conn, &wifi.device_path).await else { return };
        let before = w.last_scan().await.unwrap_or(0);
        match w.request_scan(HashMap::new()).await {
            Ok(()) => {
                state.scan_started = Some((before, Instant::now()));
                let _ = self.ui_tx.send(NetEvent::ScanStateChanged(true)).await;
            }
            Err(e) => {
                let _ = self.ui_tx.send(NetEvent::StatusMessage {
                    text: format!("No se pudo iniciar el escaneo: {e}"),
                    is_error: true,
                }).await;
            }
        }
    }

    async fn check_scan_finished(&self, conn: &Connection, state: &mut DiffState) {
        let Some((before, t0)) = state.scan_started else { return };
        let mut done = t0.elapsed() > Duration::from_secs(12);
        if let Some(wifi) = state.last_wifi.clone()
            && !wifi.device_path.is_empty()
            && let Ok(w) = build_wireless_proxy(conn, &wifi.device_path).await
        {
            let now = w.last_scan().await.unwrap_or(before);
            if now > before {
                done = true;
            }
        }
        if done {
            state.scan_started = None;
            let _ = self.ui_tx.send(NetEvent::ScanStateChanged(false)).await;
        }
    }

    // ── Comandos de la UI ────────────────────────────────────────────────────

    async fn handle_command(
        &self,
        cmd: NetCommand,
        conn: &Connection,
        nm: &NetworkManagerProxy<'_>,
        settings: &SettingsProxy<'_>,
        state: &mut DiffState,
    ) {
        match cmd {
            NetCommand::ToggleWifi => {
                let cur = nm.wireless_enabled().await.unwrap_or(false);
                let _ = nm.set_wireless_enabled(!cur).await;
            }
            NetCommand::SetWifi(v) => {
                let _ = nm.set_wireless_enabled(v).await;
            }
            NetCommand::StartScan => {
                self.start_scan(conn, state).await;
            }
            NetCommand::SetVisible(v) => {
                if v && !state.visible {
                    // Al abrir: estado fresco + escaneo inmediato
                    state.visible = true;
                    self.refresh(conn, nm, settings, state, true).await;
                    if state.scan_started.is_none() {
                        self.start_scan(conn, state).await;
                    }
                } else if !v {
                    // Al ocultar: el ticker deja de sondear (modo daemon)
                    state.visible = false;
                }
            }
            NetCommand::ConnectAp(ap_path) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let pending = self.pending.clone();
                let counter = self.req_counter.clone();
                let notify = self.refresh_notify.clone();
                let device_path = state
                    .last_wifi
                    .as_ref()
                    .map(|w| w.device_path.clone())
                    .unwrap_or_default();
                tokio::spawn(async move {
                    connect_ap_task(
                        conn2, ui_tx, pending, counter, notify, ap_path, device_path,
                    )
                    .await;
                });
            }
            NetCommand::SubmitPassword { req_id, password } => {
                let Some(req) = self.pending.lock().await.remove(&req_id) else { return };
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    let nm2 = match NetworkManagerProxy::builder(&conn2).build().await {
                        Ok(n) => n,
                        Err(e) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("Error interno: {e}"),
                                is_error: true,
                            }).await;
                            return;
                        }
                    };
                    let mut wireless: HashMap<String, OwnedValue> = HashMap::new();
                    wireless.insert("ssid".into(), ov(Value::from(req.ssid_bytes.clone())));
                    let mut conn_dict: HashMap<String, HashMap<String, OwnedValue>> =
                        HashMap::new();
                    conn_dict.insert("802-11-wireless".into(), wireless);
                    if req.key_mgmt == "none" {
                        // WEP clásico
                        let mut sec: HashMap<String, OwnedValue> = HashMap::new();
                        sec.insert("key-mgmt".into(), ov(Value::from("none")));
                        sec.insert("wep-key0".into(), ov(Value::from(password)));
                        conn_dict.insert("802-11-wireless-security".into(), sec);
                    } else {
                        let mut sec: HashMap<String, OwnedValue> = HashMap::new();
                        sec.insert("key-mgmt".into(), ov(Value::from(req.key_mgmt)));
                        sec.insert("psk".into(), ov(Value::from(password)));
                        conn_dict.insert("802-11-wireless-security".into(), sec);
                    }
                    let device = obj_path(&req.device_path);
                    let ap = obj_path(&req.ap_path);
                    match nm2
                        .add_and_activate_connection(conn_dict, device, ap)
                        .await
                    {
                        Ok(_) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("Conectando a {}…", req.ssid),
                                is_error: false,
                            }).await;
                        }
                        Err(e) => {
                            let hint = if e.to_string().to_lowercase().contains("secret") {
                                " (contraseña incorrecta)"
                            } else {
                                ""
                            };
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("No se pudo conectar a {}{}: {}", req.ssid, hint, e),
                                is_error: true,
                            }).await;
                        }
                    }
                    notify.notify_one();
                });
            }
            NetCommand::DisconnectDevice(device_path) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    if let Ok(dev) = build_device_proxy(&conn2, &device_path).await {
                        let _ = dev.disconnect().await;
                        let _ = ui_tx.send(NetEvent::StatusMessage {
                            text: "Desconectado".into(),
                            is_error: false,
                        }).await;
                    }
                    notify.notify_one();
                });
            }
            NetCommand::Forget(ap_path) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    match query_ap(&conn2, &ap_path).await {
                        Some(info) => match find_wifi_profile(&conn2, &info.ssid).await {
                            Ok(Some(profile)) => {
                                if let Ok(cproxy) = build_connection_proxy(&conn2, &profile).await {
                                    match cproxy.delete().await {
                                        Ok(()) => {
                                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                                text: format!("Red {} olvidada", info.ssid),
                                                is_error: false,
                                            }).await;
                                        }
                                        Err(e) => {
                                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                                text: format!("No se pudo olvidar la red: {e}"),
                                                is_error: true,
                                            }).await;
                                        }
                                    }
                                }
                            }
                            Ok(None) => {
                                let _ = ui_tx.send(NetEvent::StatusMessage {
                                    text: "Esta red no tiene perfil guardado".into(),
                                    is_error: true,
                                }).await;
                            }
                            Err(e) => {
                                let _ = ui_tx.send(NetEvent::StatusMessage {
                                    text: format!("Error buscando el perfil: {e}"),
                                    is_error: true,
                                }).await;
                            }
                        },
                        None => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: "La red ya no está visible".into(),
                                is_error: true,
                            }).await;
                        }
                    }
                    notify.notify_one();
                });
            }
            NetCommand::ConnectEthernet(device_path) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    let nm2 = match NetworkManagerProxy::builder(&conn2).build().await {
                        Ok(n) => n,
                        Err(e) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("Error interno: {e}"),
                                is_error: true,
                            }).await;
                            return;
                        }
                    };
                    let root = root_path();
                    let device = obj_path(&device_path);
                    // Perfil cableado existente, si lo hay
                    let mut profile: Option<OwnedObjectPath> = None;
                    if let Ok(s) = SettingsProxy::builder(&conn2).build().await
                        && let Ok(conns) = s.list_connections().await
                    {
                        for cpath in conns {
                            if let Ok(cproxy) = build_connection_proxy(&conn2, &cpath).await
                                && let Ok(all) = cproxy.get_settings().await
                                && all.get("connection")
                                    .and_then(|c| c.get("type"))
                                    .and_then(value_str)
                                    .unwrap_or_default()
                                    == "802-3-ethernet"
                            {
                                profile = Some(cpath);
                                break;
                            }
                        }
                    }
                    let res = match profile {
                        Some(p) => nm2.activate_connection(p, device, root.clone()).await,
                        None => {
                            let empty: HashMap<String, HashMap<String, OwnedValue>> =
                                HashMap::new();
                            nm2.add_and_activate_connection(empty, device, root).await.map(|_| OwnedObjectPath::default())
                        }
                    };
                    let _ = match res {
                        Ok(_) => ui_tx.send(NetEvent::StatusMessage {
                            text: "Activando conexión cableada…".into(),
                            is_error: false,
                        }).await,
                        Err(e) => ui_tx.send(NetEvent::StatusMessage {
                            text: format!("No se pudo activar la red cableada: {e}"),
                            is_error: true,
                        }).await,
                    };
                    notify.notify_one();
                });
            }
            NetCommand::ConnectVpn(uuid) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    let nm2 = match NetworkManagerProxy::builder(&conn2).build().await {
                        Ok(n) => n,
                        Err(e) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("Error interno: {e}"),
                                is_error: true,
                            }).await;
                            return;
                        }
                    };
                    let mut profile: Option<OwnedObjectPath> = None;
                    let mut name = "VPN".to_string();
                    if let Ok(s) = SettingsProxy::builder(&conn2).build().await
                        && let Ok(conns) = s.list_connections().await
                    {
                        for cpath in conns {
                            if let Ok(cproxy) = build_connection_proxy(&conn2, &cpath).await
                                && let Ok(all) = cproxy.get_settings().await
                            {
                                let sec = all.get("connection");
                                let u = sec
                                    .and_then(|c| c.get("uuid"))
                                    .and_then(value_str)
                                    .unwrap_or_default();
                                if u == uuid {
                                    name = sec
                                        .and_then(|c| c.get("id"))
                                        .and_then(value_str)
                                        .unwrap_or_else(|| "VPN".into());
                                    profile = Some(cpath);
                                    break;
                                }
                            }
                        }
                    }
                    let res = match profile {
                        Some(p) => {
                            let root = root_path();
                            nm2.activate_connection(p, root.clone(), root).await
                        }
                        None => Err(zbus::Error::Failure("Perfil VPN no encontrado".into())),
                    };
                    let _ = match res {
                        Ok(_) => ui_tx.send(NetEvent::StatusMessage {
                            text: format!("Conectando VPN {name}…"),
                            is_error: false,
                        }).await,
                        Err(e) => ui_tx.send(NetEvent::StatusMessage {
                            text: format!("No se pudo conectar la VPN {name}: {e}"),
                            is_error: true,
                        }).await,
                    };
                    notify.notify_one();
                });
            }
            NetCommand::DisconnectVpn(active_path) => {
                let ui_tx = self.ui_tx.clone();
                let conn2 = conn.clone();
                let notify = self.refresh_notify.clone();
                tokio::spawn(async move {
                    let nm2 = match NetworkManagerProxy::builder(&conn2).build().await {
                        Ok(n) => n,
                        Err(e) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("Error interno: {e}"),
                                is_error: true,
                            }).await;
                            return;
                        }
                    };
                    let active = obj_path(&active_path);
                    match nm2.deactivate_connection(active).await {
                        Ok(()) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: "VPN desconectada".into(),
                                is_error: false,
                            }).await;
                        }
                        Err(e) => {
                            let _ = ui_tx.send(NetEvent::StatusMessage {
                                text: format!("No se pudo desconectar la VPN: {e}"),
                                is_error: true,
                            }).await;
                        }
                    }
                    notify.notify_one();
                });
            }
        }
    }
}

// ── Tareas auxiliares ────────────────────────────────────────────────────────

/// Lógica de conexión a un AP: perfil conocido → ActivateConnection;
/// abierta nueva → AddAndActivateConnection; protegida nueva → pedir contraseña.
async fn connect_ap_task(
    conn: Connection,
    ui_tx: async_channel::Sender<NetEvent>,
    pending: Arc<Mutex<HashMap<u64, PendingConnect>>>,
    counter: Arc<AtomicU64>,
    notify: Arc<tokio::sync::Notify>,
    ap_path: String,
    device_path: String,
) {
    if device_path.is_empty() {
        let _ = ui_tx.send(NetEvent::StatusMessage {
            text: "No hay dispositivo Wi-Fi disponible".into(),
            is_error: true,
        }).await;
        return;
    }

    let Some(info) = query_ap(&conn, &ap_path).await else {
        let _ = ui_tx.send(NetEvent::StatusMessage {
            text: "La red ya no está visible".into(),
            is_error: true,
        }).await;
        return;
    };

    let Ok(nm) = NetworkManagerProxy::builder(&conn).build().await else { return };

    let device = obj_path(&device_path);
    let ap = obj_path(&ap_path);

    match find_wifi_profile(&conn, &info.ssid).await {
        Ok(Some(profile)) => {
            match nm.activate_connection(profile, device, ap).await {
                Ok(_) => {
                    let _ = ui_tx.send(NetEvent::StatusMessage {
                        text: format!("Conectando a {}…", info.ssid),
                        is_error: false,
                    }).await;
                }
                Err(e) => {
                    let _ = ui_tx.send(NetEvent::StatusMessage {
                        text: format!("No se pudo conectar a {}: {e}", info.ssid),
                        is_error: true,
                    }).await;
                }
            }
        }
        Ok(None) => {
            if !info.secure {
                // Red abierta: conexión directa sin contraseña
                let mut wireless: HashMap<String, OwnedValue> = HashMap::new();
                wireless.insert("ssid".into(), ov(Value::from(info.ssid.clone().into_bytes())));
                let mut conn_dict: HashMap<String, HashMap<String, OwnedValue>> =
                    HashMap::new();
                conn_dict.insert("802-11-wireless".into(), wireless);
                match nm.add_and_activate_connection(conn_dict, device, ap).await {
                    Ok(_) => {
                        let _ = ui_tx.send(NetEvent::StatusMessage {
                            text: format!("Conectando a {}…", info.ssid),
                            is_error: false,
                        }).await;
                    }
                    Err(e) => {
                        let _ = ui_tx.send(NetEvent::StatusMessage {
                            text: format!("No se pudo conectar a {}: {e}", info.ssid),
                            is_error: true,
                        }).await;
                    }
                }
            } else {
                // Red protegida nueva: pedir credenciales a la UI
                let key_mgmt: &'static str = if info.security_label == "WPA3" {
                    "sae"
                } else if info.security_label == "WEP" {
                    "none"
                } else {
                    "wpa-psk"
                };
                let req_id = counter.fetch_add(1, Ordering::SeqCst) + 1;
                pending.lock().await.insert(
                    req_id,
                    PendingConnect {
                        ap_path: ap_path.clone(),
                        device_path,
                        ssid: info.ssid.clone(),
                        ssid_bytes: info.ssid.clone().into_bytes(),
                        key_mgmt,
                    },
                );
                let _ = ui_tx.send(NetEvent::PasswordNeeded {
                    req_id,
                    ssid: info.ssid.clone(),
                    security: info.security_label.clone(),
                }).await;
            }
        }
        Err(e) => {
            let _ = ui_tx.send(NetEvent::StatusMessage {
                text: format!("Error buscando el perfil: {e}"),
                is_error: true,
            }).await;
        }
    }
    notify.notify_one();
}

/// Busca un perfil de conexión NM cuyo SSID coincida (p.ej. red guardada)
async fn find_wifi_profile(conn: &Connection, ssid: &str) -> zbus::Result<Option<OwnedObjectPath>> {
    let settings = SettingsProxy::builder(conn).build().await?;
    let ssid_bytes = ssid.as_bytes();
    for cpath in settings.list_connections().await? {
        let Ok(cproxy) = build_connection_proxy(conn, &cpath).await else { continue };
        let Ok(all) = cproxy.get_settings().await else { continue };
        if let Some(bytes) = all
            .get("802-11-wireless")
            .and_then(|w| w.get("ssid"))
            .and_then(value_bytes)
            && bytes == ssid_bytes
        {
            return Ok(Some(cpath));
        }
    }
    Ok(None)
}

// ── Constructores de proxies ─────────────────────────────────────────────────

async fn build_device_proxy<'a>(conn: &'a Connection, path: &'a str) -> zbus::Result<DeviceProxy<'a>> {
    DeviceProxy::builder(conn).path(path)?.build().await
}

async fn build_wireless_proxy<'a>(
    conn: &'a Connection,
    path: &'a str,
) -> zbus::Result<WirelessDeviceProxy<'a>> {
    WirelessDeviceProxy::builder(conn).path(path)?.build().await
}

async fn build_connection_proxy<'a>(
    conn: &'a Connection,
    path: &'a str,
) -> zbus::Result<SettingsConnectionProxy<'a>> {
    SettingsConnectionProxy::builder(conn).path(path)?.build().await
}

fn root_path() -> OwnedObjectPath {
    "/".try_into().expect("La ruta raíz '/' es un object path válido")
}

// ── Lecturas de AccessPoint / IP ─────────────────────────────────────────────

async fn query_ap(conn: &Connection, path: &str) -> Option<ApInfo> {
    let ap = AccessPointProxy::builder(conn).path(path).ok()?.build().await.ok()?;
    let ssid_bytes = ap.ssid().await.ok()?;
    let ssid = ssid_string(&ssid_bytes);
    let strength = ap.strength().await.ok()?;
    let flags = ap.flags().await.unwrap_or(0);
    let wpa = ap.wpa_flags().await.unwrap_or(0);
    let rsn = ap.rsn_flags().await.unwrap_or(0);
    let frequency = ap.frequency().await.unwrap_or(0);

    let secure = (flags & AP_FLAGS_PRIVACY) != 0 || wpa != 0 || rsn != 0;
    let security_label = if rsn & AP_SEC_KEY_MGMT_SAE != 0 {
        "WPA3"
    } else if rsn & AP_SEC_KEY_MGMT_PSK != 0 {
        "WPA2"
    } else if wpa & AP_SEC_KEY_MGMT_PSK != 0 {
        "WPA"
    } else if flags & AP_FLAGS_PRIVACY != 0 {
        "WEP"
    } else {
        "Abierta"
    };

    Some(ApInfo {
        path: path.to_string(),
        ssid,
        strength,
        secure,
        security_label: security_label.to_string(),
        frequency,
    })
}

/// IP IPv4 del dispositivo (primer address de su Ip4Config), None si no hay
async fn device_ip(conn: &Connection, device_path: &str) -> Option<String> {
    let dev = build_device_proxy(conn, device_path).await.ok()?;
    let ip4 = dev
        .ip4_config()
        .await
        .ok()
        .filter(|p| p.as_str() != "/" && !p.as_str().is_empty())?;
    let cfg = Proxy::new(conn, NM_SERVICE, ip4, "org.freedesktop.NetworkManager.IP4Config")
        .await
        .ok()?;
    let data: Vec<HashMap<String, OwnedValue>> = cfg.get_property("AddressData").await.ok()?;
    data.first()
        .and_then(|m| m.get("address"))
        .and_then(value_str)
}

// ── Ayudantes de zvariant ────────────────────────────────────────────────────

/** Convierte un Value prestado en OwnedValue para diccionarios a{sv} */
fn ov(v: Value<'static>) -> OwnedValue {
    v.try_into().expect("Conversión Value → OwnedValue infalible")
}

/** Convierte un &str en OwnedObjectPath validado */
fn obj_path(s: &str) -> OwnedObjectPath {
    ObjectPath::try_from(s)
        .expect("object path válido")
        .into()
}

fn value_bytes(v: &OwnedValue) -> Option<Vec<u8>> {
    let val: &Value<'_> = v;
    let bytes: Vec<u8> = val.clone().try_into().ok()?;
    Some(bytes)
}

fn value_str(v: &OwnedValue) -> Option<String> {
    let val: &Value<'_> = v;
    let s: String = val.clone().try_into().ok()?;
    Some(s)
}

fn ssid_string(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes)
        .trim_end_matches('\0')
        .trim()
        .to_string()
}
