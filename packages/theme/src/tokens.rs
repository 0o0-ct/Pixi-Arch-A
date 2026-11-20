//! Tokens de diseño del tema glass.
//!
//! Valores extraídos del style.css de glass-bt. Todos los componentes
//! deben usar estos tokens para mantener consistencia visual.

use gtk4::gdk::RGBA;

/// Radios de borde (en px).
pub mod radius {
    pub const PANEL: i32 = 28;
    pub const CARD: i32 = 20;
    pub const BUTTON: i32 = 14;
    pub const SQUIRCLE: i32 = 14;
    pub const DIALOG: i32 = 24;
    pub const PILL: i32 = 9999;
    pub const BADGE: i32 = 8;
    pub const SLIDER: i32 = 9999; // píldora
}

/// Espaciados (en px).
pub mod spacing {
    pub const PANEL_PADDING: i32 = 18;
    pub const PANEL_PADDING_H: i32 = 20;
    pub const CARD_PADDING_V: i32 = 10;
    pub const CARD_PADDING_H: i32 = 14;
    pub const CARD_MARGIN_BOTTOM: i32 = 7;
    pub const CONTENT_SPACING: i32 = 10;
    pub const LIST_SPACING: i32 = 4;
    pub const SQUIRCLE_MARGIN_RIGHT: i32 = 12;
    pub const BADGE_MARGIN_LEFT: i32 = 6;
    pub const SIGNAL_MARGIN_LEFT: i32 = 6;
}

/// Tamaños de iconos squircle.
pub mod icon_size {
    pub const SQUIRCLE: i32 = 44;
    pub const BUTTON: i32 = 32;
}

/// Tipografía.
pub mod typography {
    pub const PANEL_TITLE_SIZE: i32 = 17;
    pub const PANEL_SUBTITLE_SIZE: i32 = 12;
    pub const SECTION_LABEL_SIZE: i32 = 11;
    pub const DEVICE_NAME_SIZE: i32 = 13;
    pub const DEVICE_SUB_SIZE: i32 = 11;
    pub const BADGE_SIZE: i32 = 10;
    pub const DIALOG_PIN_SIZE: i32 = 28;
    pub const BUTTON_SIZE: i32 = 11;
}

/// Duraciones de animación (en ms).
pub mod animation {
    pub const FAST: u32 = 160;
    pub const NORMAL: u32 = 180;
    pub const SLOW: u32 = 220;
}

/// Nombres de clases CSS del tema.
pub mod css_class {
    // Paneles
    pub const GLASS_PANEL: &str = "glass-panel";
    pub const CONTENT_BOX: &str = "content-box";

    // Tarjetas
    pub const DEVICE_CARD: &str = "device-card";
    pub const DEVICE_CARD_CONNECTED: &str = "connected";

    // Botones
    pub const BTN_SCAN: &str = "btn-scan";
    pub const BTN_CLOSE_WINDOW: &str = "btn-close-window";
    pub const BTN_ACTION: &str = "btn-action";
    pub const BTN_CONNECT: &str = "btn-connect";
    pub const BTN_DISCONNECT: &str = "btn-disconnect";
    pub const BTN_PAIR: &str = "btn-pair";
    pub const BTN_FORGET: &str = "btn-forget";

    // Inputs
    pub const GLASS_SEARCH: &str = "glass-search";

    // Switches
    pub const IOS_SWITCH: &str = "ios-switch";

    // Iconos
    pub const DEVICE_SQUIRCLE: &str = "device-squircle";
    pub const SQUIRCLE_ACCENT: &str = "accent";
    pub const SQUIRCLE_MOUSE: &str = "mouse";
    pub const SQUIRCLE_HEADSET: &str = "headset";
    pub const SQUIRCLE_SPEAKER: &str = "speaker";
    pub const SQUIRCLE_PHONE: &str = "phone";
    pub const SQUIRCLE_WATCH: &str = "watch";
    pub const SQUIRCLE_GAMEPAD: &str = "gamepad";
    pub const SQUIRCLE_TV: &str = "tv";
    pub const SQUIRCLE_DISABLED: &str = "disabled";
    pub const SQUIRCLE_CONNECTED: &str = "connected";

    // Textos
    pub const PANEL_TITLE: &str = "panel-title";
    pub const PANEL_SUBTITLE: &str = "panel-subtitle";
    pub const SECTION_LABEL: &str = "section-label";
    pub const DEVICE_NAME: &str = "device-name";
    pub const DEVICE_SUB: &str = "device-sub";
    pub const DEVICE_SUB_CONNECTED: &str = "connected";
    pub const STATUS_DOT_GREEN: &str = "status-dot-green";
    pub const STATUS_DOT_DIM: &str = "status-dot-dim";
    pub const BADGE_BATTERY: &str = "badge-battery";

    // Señal
    pub const SIGNAL_BOX: &str = "signal-box";
    pub const SIGNAL_BAR: &str = "signal-bar";
    pub const SIGNAL_BAR_ACTIVE: &str = "active";

    // Diálogo
    pub const DIALOG_BOX: &str = "dialog-box";
    pub const DIALOG_PIN: &str = "dialog-pin";
}

/// Colores dinámicos (inyectados por Wallust/Matugen en runtime).
/// Estos son los nombres de las variables CSS que se definen en colors-waybar.css.
pub mod color_var {
    pub const PRIMARY: &str = "@primary";
    pub const SECONDARY: &str = "@secondary";
    pub const TERTIARY: &str = "@tertiary";
    pub const SURFACE: &str = "@surface";
    pub const ON_SURFACE: &str = "@on_surface";
    pub const FOREGROUND: &str = "@foreground";
    pub const COLOR15: &str = "@color15";
    pub const PRIMARY_CONTAINER: &str = "@primary_container";
    pub const ON_PRIMARY: &str = "@on_primary";
    pub const ACCENT_GLOW: &str = "@accent_glow";
    pub const ACCENT_TINT: &str = "@accent_tint";
    pub const ACCENT_BORDER: &str = "@accent_border";
    pub const DANGER_RED: &str = "#ffb4ab";
    pub const DANGER_BG: &str = "@danger_bg";
    pub const DANGER_BORDER: &str = "@danger_border";
}