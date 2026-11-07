use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeviceType {
    Mouse,
    Keyboard,
    Headset,
    Speaker,
    Phone,
    Watch,
    Computer,
    Tv,
    Gamepad,
    Generic,
}

impl DeviceType {
    pub fn from_icon_and_name(icon: Option<&str>, name: &str) -> Self {
        let lower = name.to_lowercase();
        // 1. Chequeo por nombre específico primero (marcas y tipos claros de audio/dispositivo)
        if lower.contains("speaker")
            || lower.contains("parlante")
            || lower.contains("altavoz")
            || lower.contains("sound party")
            || lower.contains("partybox")
            || lower.contains("boombox")
            || lower.contains("soundcore")
            || lower.contains("soundlink")
            || (lower.contains("sound") && !lower.contains("bud"))
        {
            return DeviceType::Speaker;
        } else if lower.contains("gamepad")
            || lower.contains("controller")
            || lower.contains("joystick")
            || lower.contains("xbox")
            || lower.contains("dualshock")
            || lower.contains("dualsense")
            || lower.contains("mando")
        {
            return DeviceType::Gamepad;
        } else if lower.contains("mouse") || lower.contains("ratón") || lower.contains("raton") {
            return DeviceType::Mouse;
        } else if lower.contains("keyboard") || lower.contains("teclado") {
            return DeviceType::Keyboard;
        } else if lower.contains("headset")
            || lower.contains("headphones")
            || lower.contains("auricular")
            || lower.contains("audifono")
            || lower.contains("audífono")
            || lower.contains("buds")
            || lower.contains("tune")
            || lower.contains("beam")
            || lower.contains("airpod")
            || lower.contains("bt20")
            || lower.contains("ear")
        {
            return DeviceType::Headset;
        } else if lower.contains("phone")
            || lower.contains("iphone")
            || lower.contains("galaxy")
            || lower.contains("xiaomi")
            || lower.contains("teléfono")
            || lower.contains("telefono")
            || lower.contains("k1ev3r")
        {
            return DeviceType::Phone;
        } else if lower.contains("watch") || lower.contains("reloj") || lower.contains("fitbit") || lower.contains("band") {
            return DeviceType::Watch;
        } else if lower.contains("tv") || lower.contains("box") || lower.contains("chromecast") {
            return DeviceType::Tv;
        } else if lower.contains("laptop") || lower.contains("pc") || lower.contains("computadora") {
            return DeviceType::Computer;
        }

        // 2. Si el nombre no dio pistas claras, confiar en el icono reportado por BlueZ
        if let Some(i) = icon {
            match i {
                "input-mouse" => return DeviceType::Mouse,
                "input-keyboard" => return DeviceType::Keyboard,
                "input-gaming" => return DeviceType::Gamepad,
                "audio-headset" | "audio-headphones" => return DeviceType::Headset,
                "audio-speaker" | "audio-card" => return DeviceType::Speaker,
                "phone" => return DeviceType::Phone,
                "watch" => return DeviceType::Watch,
                "computer" => return DeviceType::Computer,
                "video-display" | "tv" => return DeviceType::Tv,
                _ => {}
            }
        }

        DeviceType::Generic
    }

    pub fn to_gtk_icon(self) -> &'static str {
        match self {
            DeviceType::Mouse => "input-mouse-symbolic",
            DeviceType::Keyboard => "input-keyboard-symbolic",
            DeviceType::Headset => "audio-headphones-symbolic",
            DeviceType::Speaker => "audio-speakers-symbolic",
            DeviceType::Phone => "phone-symbolic",
            DeviceType::Watch => "watch-symbolic",
            DeviceType::Computer => "computer-symbolic",
            DeviceType::Tv => "tv-symbolic",
            DeviceType::Gamepad => "input-gaming-symbolic",
            DeviceType::Generic => "bluetooth-active-symbolic",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            DeviceType::Mouse => "Ratón",
            DeviceType::Keyboard => "Teclado",
            DeviceType::Headset => "Audífonos",
            DeviceType::Speaker => "Altavoz",
            DeviceType::Phone => "Teléfono",
            DeviceType::Watch => "Reloj",
            DeviceType::Computer => "Computadora",
            DeviceType::Tv => "Televisor",
            DeviceType::Gamepad => "Control de juego",
            DeviceType::Generic => "Dispositivo",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub mac: String,
    pub name: String,
    pub alias: Option<String>,
    pub device_type: DeviceType,
    pub paired: bool,
    pub connected: bool,
    pub trusted: bool,
    pub battery_percentage: Option<u8>,
    pub rssi: Option<i16>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PairingKind {
    ConfirmPin(u32),
    DisplayPin(u32),
    RequestPin,
    Authorize,
}

#[derive(Debug, Clone)]
pub struct PairingRequest {
    pub req_id: u64,
    pub device_mac: String,
    pub device_name: String,
    pub kind: PairingKind,
}

#[derive(Debug, Clone)]
pub enum BtCommand {
    TogglePower,
    SetPower(bool),
    StartScan,
    StopScan,
    ToggleScan,
    Connect(String),
    Disconnect(String),
    Pair(String),
    Forget(String),
    SetTrusted(String, bool),
    PairingResponse {
        req_id: u64,
        accept: bool,
        pin_code: Option<String>,
    },
}

#[derive(Debug, Clone)]
pub enum BtEvent {
    AdapterStatus {
        powered: bool,
        discovering: bool,
        name: String,
        address: String,
    },
    DeviceAdded(DeviceInfo),
    DeviceUpdated(DeviceInfo),
    DeviceRemoved(String),
    ScanStateChanged(bool),
    PairingPrompt(PairingRequest),
    StatusMessage {
        text: String,
        is_error: bool,
    },
}

