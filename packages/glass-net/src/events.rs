/// Estado de un punto de acceso Wi-Fi visible (organizado por NetworkManager)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ApInfo {
    /// Ruta del objeto D-Bus del AccessPoint (identificador único)
    pub path: String,
    pub ssid: String,
    /// Intensidad de señal 0-100 (propiedad Strength de NM)
    pub strength: u8,
    /// ¿Red protegida? (candado)
    pub secure: bool,
    /// Etiqueta de seguridad: "Abierta", "WPA/WPA2", "WPA3", "WEP"…
    pub security_label: String,
    /// Canal / frecuencia en MHz (0 si desconocido)
    pub frequency: u32,
}

/// Estado del dispositivo Ethernet cableado
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EthernetInfo {
    /// Ruta del objeto D-Bus del Device ("" si no hay)
    pub device_path: String,
    pub interface: String,
    /// NM Device State: 100 = Activado, 40-90 = Conectando, 30 = Desconectado…
    pub state: u32,
    pub ip: Option<String>,
}

/// Estado del dispositivo Wi-Fi
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WifiDeviceInfo {
    pub present: bool,
    pub device_path: String,
    pub interface: String,
    /// SSID de la red activa (None si no conectado)
    pub connected_ssid: Option<String>,
    pub ip: Option<String>,
    /// ¿Está activándose una conexión en este momento? (estado 40-90)
    pub activating: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VpnInfo {
    /// UUID del perfil de conexión VPN
    pub uuid: String,
    pub name: String,
    pub active: bool,
    /// Ruta de la ActiveConnection si está activa (para desconectar)
    pub active_path: String,
}

/// Comandos UI → backend (molde BtCommand de glass-bt)
#[derive(Debug, Clone)]
pub enum NetCommand {
    /// Ventana visible u oculta: oculto → pausar polling/escaneo (modo daemon)
    SetVisible(bool),
    ToggleWifi,
    SetWifi(bool),
    StartScan,
    /// Conectar a un AccessPoint por su ruta D-Bus (pide contraseña si hace falta)
    ConnectAp(String),
    /// Desconectar un dispositivo (ruta D-Bus del Device)
    DisconnectDevice(String),
    /// Olvidar una red: borra el perfil NM asociado al AP
    Forget(String),
    /// Activar la conexión cableada del dispositivo indicado
    ConnectEthernet(String),
    /// Conectar VPN por UUID
    ConnectVpn(String),
    /// Desactivar VPN por ruta de ActiveConnection
    DisconnectVpn(String),
    /// Respuesta del diálogo de contraseña Wi-Fi
    SubmitPassword { req_id: u64, password: String },
}

/// Eventos backend → UI (molde BtEvent de glass-bt)
#[derive(Debug, Clone)]
pub enum NetEvent {
    /// Estado de los radios de NetworkManager
    NmStatus { wifi_enabled: bool, networking_enabled: bool },
    WifiDevice(WifiDeviceInfo),
    EthernetState(EthernetInfo),
    ApAdded(ApInfo),
    ApUpdated(ApInfo),
    ApRemoved(String),
    /// Lista de SSIDs con perfil guardado en NM (recalculada tras cambios)
    KnownSsids(Vec<String>),
    Vpns(Vec<VpnInfo>),
    ScanStateChanged(bool),
    /// El backend necesita credenciales para esta red protegida
    PasswordNeeded { req_id: u64, ssid: String, security: String },
    StatusMessage { text: String, is_error: bool },
}
