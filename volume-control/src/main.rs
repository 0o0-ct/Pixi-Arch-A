//! # Control de Volumen - Pixi-Arch-A (ONE UI 8.5 + Glassmorphism)
//!
//! Control de volumen moderno en Rust + Iced que se adapta dinámicamente a la
//! paleta del wallpaper (Matugen/Wallust via qml_color.json y colors-waybar.css).
//! Diseño inspirado en ONE UI 8.5: tarjetas glass, animaciones fluidas, tipografía
//! variable, bordes suaves, sombras en capas.
//!
//! Construcción:
//!   cd /home/c0o0c/JaKooLit/volume-control
//!   cargo build --release
//!
//! Uso:
//!   ./target/release/volume-control          # Abre la GUI
//!   ./target/release/volume-control --get    # Imprime el volumen actual
//!   ./target/release/volume-control --inc    # Sube el volumen
//!   ./target/release/volume-control --dec    # Baja el volumen
//!   ./target/release/volume-control --toggle # Silencia/desilencia
//!   ./target/release/volume-control --inc-precise  # Sube 1%
//!   ./target/release/volume-control --dec-precise  # Baja 1%

use iced::{
    widget::{button, column, container, row, slider, text, Space},
    application, Color, Element, Length, Alignment, Settings, Task, Theme,
    window::{self, Settings as WindowSettings, Level},
    Size, Padding, Border, Shadow, Vector,
    time,
};
use std::{
    collections::HashMap,
    default::Default,
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

/// Carga la paleta dinámica desde qml_color.json (generado por pixi_colors.py / Matugen)
/// y/o colors-waybar.css (Wallust ANSI + Material 3).
#[derive(Debug, Clone, serde::Deserialize)]
struct QmlColor {
    #[serde(rename = "windowBackground")]
    window_background: String,
    #[serde(rename = "primaryText")]
    primary_text: String,
    #[serde(rename = "layerBackground1")]
    layer_background_1: String,
    #[serde(rename = "layerBackground2")]
    layer_background_2: String,
    #[serde(rename = "layerBackground3")]
    layer_background_3: String,
    #[serde(rename = "accentPrimary")]
    accent_primary: String,
    #[serde(rename = "accentSecondary")]
    accent_secondary: String,
    #[serde(rename = "selectionBackground")]
    selection_background: String,
    #[serde(rename = "borderPrimary")]
    border_primary: String,
    #[serde(rename = "m3")]
    m3: M3Colors,
    mode: String,
    glass: String,
}

#[derive(Debug, Clone, serde::Deserialize)]
struct M3Colors {
    primary: String,
    on_primary: String,
    #[serde(rename = "primary_container")]
    primary_container: String,
    #[serde(rename = "on_primary_container")]
    on_primary_container: String,
    secondary: String,
    tertiary: String,
    surface: String,
    background: String,
    #[serde(rename = "on_surface")]
    on_surface: String,
    #[serde(rename = "surface_variant")]
    surface_variant: String,
    #[serde(rename = "on_surface_variant")]
    on_surface_variant: String,
    #[serde(rename = "outline")]
    outline: String,
    #[serde(rename = "outline_variant")]
    outline_variant: String,
    error: String,
    #[serde(rename = "color15")]
    color15: Option<String>,
}

impl Default for M3Colors {
    fn default() -> Self {
        Self {
            primary: "#e4b7f3".into(),
            on_primary: "#442253".into(),
            primary_container: "#5d386b".into(),
            on_primary_container: "#f8d8ff".into(),
            secondary: "#d4c0d7".into(),
            tertiary: "#f5b7b5".into(),
            surface: "#161217".into(),
            background: "#161217".into(),
            on_surface: "#e9e0e7".into(),
            surface_variant: "#4c444d".into(),
            on_surface_variant: "#cec3cd".into(),
            outline: "#978e97".into(),
            outline_variant: "#4c444d".into(),
            error: "#ffb4ab".into(),
            color15: Some("#f8d8ff".into()),
        }
    }
}

/// Paleta de colores completa para la UI (ONE UI 8.5 style).
#[derive(Debug, Clone)]
struct Palette {
    // Base surfaces
    window_bg: Color,
    surface_1: Color,
    surface_2: Color,
    surface_3: Color,

    // Text
    text_primary: Color,
    text_secondary: Color,
    text_dim: Color,

    // Accent / Brand
    accent: Color,
    accent_secondary: Color,
    accent_container: Color,
    on_accent: Color,
    on_accent_container: Color,

    // Glass / Frosted
    glass_bg: Color,
    glass_border: Color,
    glass_shadow: Color,
    glass_highlight: Color,
    glass_sheen: Color,

    // Interactive
    border_subtle: Color,
    border_focus: Color,
    hover_overlay: Color,
    press_overlay: Color,
    selection_bg: Color,

    // States
    danger: Color,
    danger_bg: Color,
    danger_border: Color,
    warning: Color,
    success: Color,

    // M3 full
    m3: M3Colors,

    mode: String,
    glass_mode: String,
}

impl Palette {
    /// Carga la paleta desde archivos del sistema (qml_color.json + colors-waybar.css)
    fn load() -> Self {
        // Primero intenta qml_color.json (fuente principal Matugen)
        let qml = Self::load_qml_colors();
        let mut palette = Self::from_qml(&qml);

        // Enriquece con colors-waybar.css para ANSI + M3 roles completos
        let css = Self::parse_waybar_colors_static();
        palette.merge_waybar(css);

        palette
    }

    fn load_qml_colors() -> QmlColor {
        let paths = [
            dirs_next::home_dir().map(|h| h.join(".config/quickshell/qml_color.json")),
            Some(PathBuf::from("/home/c0o0c/.config/quickshell/qml_color.json")),
        ];

        for path in paths {
            if let Some(p) = path {
                if let Ok(content) = fs::read_to_string(&p) {
                    if let Ok(qml) = serde_json::from_str::<QmlColor>(&content) {
                        return qml;
                    }
                }
            }
        }

        // Fallback por defecto
        QmlColor {
            window_background: "#161217".into(),
            primary_text: "#e9e0e7".into(),
            layer_background_1: "#2d282e".into(),
            layer_background_2: "#231e23".into(),
            layer_background_3: "#1f1a1f".into(),
            accent_primary: "#e4b7f3".into(),
            accent_secondary: "#f5b7b5".into(),
            selection_background: "#5d386b".into(),
            border_primary: "#4c444d".into(),
            m3: M3Colors::default(),
            mode: "dark".into(),
            glass: "dark".into(),
        }
    }

    fn from_qml(qml: &QmlColor) -> Self {
        let accent = Self::parse_hex(&qml.accent_primary).unwrap_or(Color::from_rgb(0.89, 0.72, 0.95));
        let accent_sec = Self::parse_hex(&qml.accent_secondary).unwrap_or(Color::from_rgb(0.96, 0.72, 0.71));
        let surface_1 = Self::parse_hex(&qml.layer_background_1).unwrap_or(Color::from_rgb(0.176, 0.157, 0.18));
        let surface_2 = Self::parse_hex(&qml.layer_background_2).unwrap_or(Color::from_rgb(0.137, 0.118, 0.137));
        let surface_3 = Self::parse_hex(&qml.layer_background_3).unwrap_or(Color::from_rgb(0.122, 0.102, 0.122));
        let text_pri = Self::parse_hex(&qml.primary_text).unwrap_or(Color::from_rgb(0.91, 0.88, 0.91));
        let text_sec = Self::parse_hex(&qml.primary_text).map(|c| Color { a: 0.72, ..c }).unwrap_or(Color { a: 0.72, ..text_pri });
        let _border_pri = Self::parse_hex(&qml.border_primary).unwrap_or(Color::from_rgb(0.30, 0.267, 0.302));
        let sel_bg = Self::parse_hex(&qml.selection_background).unwrap_or(Color::from_rgb(0.365, 0.22, 0.42));

        // Glass tokens (frosted glass)
        let color15 = qml.m3.color15.as_deref().and_then(Self::parse_hex).unwrap_or(Color::WHITE);
        let primary = Self::parse_hex(&qml.m3.primary).unwrap_or(accent);
        let surface = Self::parse_hex(&qml.m3.surface).unwrap_or(surface_1);
        let _on_surface = Self::parse_hex(&qml.m3.on_surface).unwrap_or(text_pri);

        Self {
            window_bg: Self::parse_hex(&qml.window_background).unwrap_or(Color::from_rgb(0.086, 0.071, 0.09)),
            surface_1,
            surface_2,
            surface_3,
            text_primary: text_pri,
            text_secondary: text_sec,
            text_dim: Color { a: 0.45, ..text_pri },
            accent,
            accent_secondary: accent_sec,
            accent_container: Self::parse_hex(&qml.m3.primary_container).unwrap_or(Color::from_rgb(0.365, 0.22, 0.42)),
            on_accent: Self::parse_hex(&qml.m3.on_primary).unwrap_or(Color::from_rgb(0.267, 0.133, 0.325)),
            on_accent_container: Self::parse_hex(&qml.m3.on_primary_container).unwrap_or(Color::from_rgb(0.97, 0.85, 1.0)),
            border_subtle: Color { a: 0.12, ..color15 },
            border_focus: primary,
            hover_overlay: Color { a: 0.08, ..color15 },
            press_overlay: Color { a: 0.14, ..color15 },
            selection_bg: sel_bg,

            // Glass / Frosted
            glass_bg: Color { a: 0.38, ..surface },
            glass_border: Color { a: 0.22, ..color15 },
            glass_shadow: Color { a: 0.45, ..Color::BLACK },
            glass_highlight: Color { a: 0.35, ..color15 },
            glass_sheen: Color { a: 0.75, ..color15 },

            danger: Self::parse_hex(&qml.m3.error).unwrap_or(Color::from_rgb(1.0, 0.706, 0.671)),
            danger_bg: Color { a: 0.18, ..Self::parse_hex(&qml.m3.error).unwrap_or(Color::from_rgb(1.0, 0.706, 0.671)) },
            danger_border: Color { a: 0.40, ..Self::parse_hex(&qml.m3.error).unwrap_or(Color::from_rgb(1.0, 0.706, 0.671)) },
            warning: Color::from_rgb(1.0, 0.78, 0.3),
            success: Color::from_rgb(0.48, 0.87, 0.56),

            m3: qml.m3.clone(),
            mode: qml.mode.clone(),
            glass_mode: qml.glass.clone(),
        }
    }

    fn parse_waybar_colors_static() -> HashMap<String, String> {
        let path = dirs_next::home_dir()
            .map(|h| h.join(".config/waybar/wallust/colors-waybar.css"))
            .unwrap_or_else(|| PathBuf::from("/home/c0o0c/.config/waybar/wallust/colors-waybar.css"));

        let mut map = HashMap::new();
        if let Ok(content) = fs::read_to_string(&path) {
            for line in content.lines() {
                let line = line.trim();
                if line.starts_with("@define-color") {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 3 {
                        let name = parts[1].to_string();
                        let value = parts[2].trim_end_matches(';').to_string();
                        map.insert(name, value);
                    }
                }
            }
        }
        map
    }

    fn merge_waybar(&mut self, css: HashMap<String, String>) {
        if let Some(v) = css.get("primary") { self.accent = Self::parse_css_hex(v).unwrap_or(self.accent); }
        if let Some(v) = css.get("on_primary") { self.on_accent = Self::parse_css_hex(v).unwrap_or(self.on_accent); }
        if let Some(v) = css.get("primary_container") { self.accent_container = Self::parse_css_hex(v).unwrap_or(self.accent_container); }
        if let Some(v) = css.get("on_primary_container") { self.on_accent_container = Self::parse_css_hex(v).unwrap_or(self.on_accent_container); }
        if let Some(v) = css.get("secondary") { self.accent_secondary = Self::parse_css_hex(v).unwrap_or(self.accent_secondary); }
        if let Some(v) = css.get("tertiary") { self.warning = Self::parse_css_hex(v).unwrap_or(self.warning); }
        if let Some(v) = css.get("surface") { self.surface_1 = Self::parse_css_hex(v).unwrap_or(self.surface_1); }
        if let Some(v) = css.get("on_surface") { self.text_primary = Self::parse_css_hex(v).unwrap_or(self.text_primary); }
        if let Some(v) = css.get("color15") { 
            let c = Self::parse_css_hex(v).unwrap_or(Color::WHITE);
            self.glass_sheen = Color { a: 0.75, ..c };
            self.glass_highlight = Color { a: 0.35, ..c };
            self.glass_border = Color { a: 0.22, ..c };
        }
        if let Some(v) = css.get("outline_variant") { self.border_subtle = Self::parse_css_hex(v).unwrap_or(self.border_subtle); }
        if let Some(v) = css.get("error") { self.danger = Self::parse_css_hex(v).unwrap_or(self.danger); }
    }

    fn parse_hex(s: &str) -> Option<Color> {
        let s = s.trim_start_matches('#');
        if s.len() == 6 {
            let r = u8::from_str_radix(&s[0..2], 16).ok()?;
            let g = u8::from_str_radix(&s[2..4], 16).ok()?;
            let b = u8::from_str_radix(&s[4..6], 16).ok()?;
            Some(Color::from_rgb8(r, g, b))
        } else if s.len() == 8 {
            let r = u8::from_str_radix(&s[0..2], 16).ok()?;
            let g = u8::from_str_radix(&s[2..4], 16).ok()?;
            let b = u8::from_str_radix(&s[4..6], 16).ok()?;
            let a = u8::from_str_radix(&s[6..8], 16).ok()?;
            Some(Color::from_rgba8(r, g, b, a as f32 / 255.0))
        } else {
            None
        }
    }

    fn parse_css_hex(s: &str) -> Option<Color> {
        // Maneja formatos: #rrggbb, #rrggbbaa, rgb(...), rgba(...)
        let s = s.trim();
        if s.starts_with('#') {
            Self::parse_hex(s)
        } else if s.starts_with("rgb(") || s.starts_with("rgba(") {
            let inner = s.trim_start_matches("rgb(").trim_start_matches("rgba(").trim_end_matches(')');
            let parts: Vec<&str> = inner.split(',').collect();
            if parts.len() >= 3 {
                let r = parts[0].trim().parse::<f32>().ok()? / 255.0;
                let g = parts[1].trim().parse::<f32>().ok()? / 255.0;
                let b = parts[2].trim().parse::<f32>().ok()? / 255.0;
                let a = parts.get(3).and_then(|s| s.trim().parse::<f32>().ok()).unwrap_or(1.0);
                Some(Color { r, g, b, a })
            } else {
                None
            }
        } else {
            None
        }
    }
}

/// Estado global compartido (para hot-reload de colores)
static PALETTE: std::sync::OnceLock<Arc<Mutex<Palette>>> = std::sync::OnceLock::new();

fn palette() -> Arc<Mutex<Palette>> {
    PALETTE.get_or_init(|| Arc::new(Mutex::new(Palette::load()))).clone()
}

/// Inicia watcher de archivos para hot-reload de colores
fn start_color_watcher() {
    let palette_arc = palette();
    std::thread::spawn(move || {
        let paths = [
            dirs_next::home_dir().map(|h| h.join(".config/quickshell/qml_color.json")),
            dirs_next::home_dir().map(|h| h.join(".config/waybar/wallust/colors-waybar.css")),
        ];
        let mut last_mod = std::time::SystemTime::UNIX_EPOCH;
        loop {
            std::thread::sleep(Duration::from_secs(2));
            let mut changed = false;
            for path in &paths {
                if let Some(p) = path {
                    if let Ok(meta) = fs::metadata(p) {
                        if let Ok(m) = meta.modified() {
                            if m > last_mod {
                                last_mod = m;
                                changed = true;
                            }
                        }
                    }
                }
            }
            if changed {
                if let Ok(mut p) = palette_arc.lock() {
                    *p = Palette::load();
                }
                // La UI se actualizará en el próximo frame
            }
        }
    });
}

/// Estado del control de volumen.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Status {
    #[default]
    Normal,
    Muted,
}

/// Mensajes de la UI.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Message {
    VolumeChanged(u32),
    ToggleMute,
    Quit,
    Tick(Instant),
    ReloadColors,
}

/// Controlador de audio (PipeWire vía pamixer).
struct AudioController;

impl AudioController {
    fn new() -> Self { Self }

    fn get_status(&self) -> (u32, bool) {
        let level = std::process::Command::new("pamixer")
            .arg("--get-volume")
            .output()
            .ok()
            .and_then(|o| String::from_utf8_lossy(&o.stdout).trim().parse().ok())
            .unwrap_or(0);

        let muted = std::process::Command::new("pamixer")
            .arg("--get-mute")
            .output()
            .ok()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "true")
            .unwrap_or(false);

        (level, muted || level == 0)
    }

    fn set_volume(&self, level: u32) {
        let _ = std::process::Command::new("pamixer")
            .arg("--set-volume")
            .arg(level.to_string())
            .arg("--allow-boost")
            .arg("--set-limit")
            .arg("150")
            .status();
    }

    fn toggle_mute(&self) {
        let _ = std::process::Command::new("pamixer").arg("-t").status();
    }

    fn increase(&self, step: u32) {
        let _ = std::process::Command::new("pamixer")
            .arg("-i")
            .arg(step.to_string())
            .arg("--allow-boost")
            .arg("--set-limit")
            .arg("150")
            .status();
    }

    fn decrease(&self, step: u32) {
        let _ = std::process::Command::new("pamixer").arg("-d").arg(step.to_string()).status();
    }
}

/// Widget principal.
struct VolumeControl {
    audio: AudioController,
    level: u32,
    muted: bool,
    status: Status,
    palette: Arc<Mutex<Palette>>,
    anim_progress: f32,
    anim_target: f32,
    show_glow: bool,
    hover_mute: bool,
    hover_close: bool,
}

impl Default for VolumeControl {
    fn default() -> Self {
        let audio = AudioController::new();
        let (level, muted) = audio.get_status();
        let palette = palette();

        // Iniciar watcher de colores
        start_color_watcher();

        Self {
            audio,
            level,
            muted,
            status: if muted { Status::Muted } else { Status::Normal },
            palette,
            anim_progress: 0.0,
            anim_target: 0.0,
            show_glow: false,
            hover_mute: false,
            hover_close: false,
        }
    }
}

/// Actualiza el estado.
fn update(state: &mut VolumeControl, message: Message) -> Task<Message> {
    match message {
        Message::VolumeChanged(value) => {
            state.level = value;
            state.anim_target = (value as f32 / 150.0).clamp(0.0, 1.0);
            if state.muted && value > 0 {
                state.muted = false;
                state.status = Status::Normal;
            }
            state.audio.set_volume(value);
            state.show_glow = true;
            Task::none()
        }
        Message::ToggleMute => {
            state.audio.toggle_mute();
            state.muted = !state.muted;
            state.status = if state.muted { Status::Muted } else { Status::Normal };
            state.show_glow = true;
            Task::none()
        }
        Message::Quit => std::process::exit(0),
        Message::Tick(now) => {
            // Animación suave del slider (ONE UI spring feel)
            let diff = state.anim_target - state.anim_progress;
            if diff.abs() > 0.001 {
                state.anim_progress += diff * 0.18; // spring damping ~0.82
            }
            // Auto-hide glow
            if state.show_glow && now.elapsed() > Duration::from_millis(600) {
                state.show_glow = false;
            }
            // Hot-reload check
            Task::none()
        }
        Message::ReloadColors => {
            *state.palette.lock().unwrap() = Palette::load();
            Task::none()
        }
    }
}

/// Easing ONE UI 8.5 (cubic-bezier(0.22, 1, 0.36, 1) aproximado)
fn one_ui_ease(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    // Aproximación: t * t * (3.0 - 2.0 * t) con overshoot suave
    t * t * (3.0 - 2.0 * t) + 0.08 * (t * (1.0 - t)).sqrt() * (1.0 - (2.0 * t - 1.0).powi(2))
}

/// Renderiza la vista con estilo ONE UI 8.5 + Glassmorphism.
fn view(state: &VolumeControl) -> Element<'_, Message, Theme, iced::Renderer> {
    // Clona los valores de la paleta para usar en closures
    let palette = state.palette.lock().unwrap().clone();

    // Icono de volumen según nivel y mute (Material Symbols style)
    let icon = if state.muted || state.level == 0 {
        "󰝟"
    } else if state.level <= 30 {
        "󰕿"
    } else if state.level <= 70 {
        "󰖀"
    } else {
        "󰕾"
    };

    // Header: icono + título + subtítulo
    let header = row![
        text(icon)
            .size(36)
            .style(move |_| text::Style { color: Some(palette.accent) }),
        column![
            text("Control de Volumen").size(22).style(move |_| text::Style { 
                color: Some(palette.text_primary) 
            }),
            text(if state.muted { "Silenciado" } else { "Volumen del sistema" })
                .size(13)
                .style(move |_| text::Style { color: Some(palette.text_secondary) }),
        ]
        .spacing(3)
        .align_x(Alignment::Start),
    ]
    .spacing(18)
    .align_y(Alignment::Center);

    // Slider estilo ONE UI 8.5: track grueso (6px), handle circular (20px), 
    // relleno con gradiente del acento, rail sutil
    let slider_value = state.anim_progress * 150.0;
    let volume_slider = slider(
        0.0..=150.0,
        slider_value,
        |v| Message::VolumeChanged(v as u32),
    )
    .width(Length::Fill)
    .style(move |_theme, _status| {
        let rail_h = 6.0;
        let handle_r = 10.0;

        // Colores del rail
        let (rail_bg, rail_fill) = if state.muted || state.level == 0 {
            (palette.surface_3, palette.text_dim)
        } else {
            (palette.surface_3, palette.accent)
        };

        // Handle color
        let handle_bg = if state.muted || state.level == 0 {
            palette.text_dim
        } else {
            palette.accent
        };

        // Glow cuando show_glow
        let _glow = if state.show_glow && !state.muted {
            Shadow {
                color: Color { a: 0.45, ..palette.accent },
                offset: Vector::new(0.0, 0.0),
                blur_radius: 16.0,
            }
        } else {
            Shadow::default()
        };

        iced::widget::slider::Style {
            rail: iced::widget::slider::Rail {
                backgrounds: (
                    iced::Background::Color(rail_bg),
                    iced::Background::Color(rail_fill),
                ),
                width: rail_h,
                border: Border {
                    color: Color::TRANSPARENT,
                    width: 0.0,
                    radius: (rail_h / 2.0).into(),
                },
            },
            handle: iced::widget::slider::Handle {
                shape: iced::widget::slider::HandleShape::Circle { radius: handle_r },
                background: iced::Background::Color(handle_bg),
                border_width: 0.0,
                border_color: Color::TRANSPARENT,
            },
        }
    });

    // Porcentaje grande (ONE UI: tipografía variable, peso 600)
    let percent = text(format!("{}%", state.level))
        .size(48)
        .style(move |_| text::Style {
            color: Some(if state.muted || state.level == 0 {
                palette.text_dim
            } else {
                palette.accent
            }),
        });

    // Botón de mute (píldora glass)
    let mute_button = button(
        text(if state.muted { "󰝟" } else { "󰕾" }).size(22)
    )
    .padding(Padding { top: 12.0, bottom: 12.0, left: 16.0, right: 16.0 })
    .on_press(Message::ToggleMute)
    .style(move |_theme, status| {
        let is_hover = matches!(status, iced::widget::button::Status::Hovered);
        let is_pressed = matches!(status, iced::widget::button::Status::Pressed);

        let (bg, text_color, border_col, shadow) = if state.muted {
            (palette.danger_bg, palette.danger, palette.danger_border, Shadow {
                color: Color { a: 0.25, ..palette.danger },
                offset: Vector::new(0.0, 2.0),
                blur_radius: 8.0,
            })
        } else if is_pressed {
            (Color { a: palette.press_overlay.a, ..palette.surface_2 }, palette.text_primary, palette.border_subtle, Shadow::default())
        } else if is_hover {
            (Color { a: palette.hover_overlay.a, ..palette.surface_2 }, palette.text_primary, palette.accent, Shadow {
                color: Color { a: 0.18, ..palette.accent },
                offset: Vector::new(0.0, 2.0),
                blur_radius: 10.0,
            })
        } else {
            (palette.surface_2, palette.text_primary, palette.border_subtle, Shadow {
                color: palette.glass_shadow,
                offset: Vector::new(0.0, 1.0),
                blur_radius: 4.0,
            })
        };

        iced::widget::button::Style {
            background: Some(iced::Background::Color(bg)),
            text_color,
            border: Border { color: border_col, width: 1.0, radius: 12.0.into() },
            shadow,
            ..Default::default()
        }
    });

    // Botón cerrar (píldora glass sutil)
    let close_button = button(text("Cerrar").size(13))
        .padding(Padding { top: 10.0, bottom: 10.0, left: 18.0, right: 18.0 })
        .on_press(Message::Quit)
        .style(move |_theme, status| {
            let is_hover = matches!(status, iced::widget::button::Status::Hovered);
            let is_pressed = matches!(status, iced::widget::button::Status::Pressed);

            let (bg, text_color, border_col) = if is_pressed {
                (Color { a: palette.press_overlay.a, ..palette.surface_3 }, palette.text_secondary, palette.border_subtle)
            } else if is_hover {
                (palette.danger_bg, palette.danger, palette.danger_border)
            } else {
                (palette.surface_3, palette.text_secondary, palette.border_subtle)
            };

            iced::widget::button::Style {
                background: Some(iced::Background::Color(bg)),
                text_color,
                border: Border { color: border_col, width: 1.0, radius: 12.0.into() },
                shadow: if is_hover {
                    Shadow { color: Color { a: 0.25, ..palette.danger }, offset: Vector::new(0.0, 2.0), blur_radius: 8.0 }
                } else { Shadow::default() },
                ..Default::default()
            }
        });

    let controls = row![mute_button, Space::with_width(12.0), close_button]
        .align_y(Alignment::Center)
        .width(Length::Fill);

    // Contenido principal
    let content = column![
        Space::with_height(8),
        header,
        Space::with_height(16),
        container(volume_slider)
            .padding(Padding { top: 24.0, bottom: 24.0, left: 8.0, right: 8.0 })
            .width(Length::Fill),
        Space::with_height(12),
        container(row![percent].align_y(Alignment::Center).width(Length::Fill))
            .width(Length::Fill),
        Space::with_height(20),
        container(controls)
            .padding(Padding { top: 16.0, bottom: 16.0, left: 8.0, right: 8.0 })
            .width(Length::Fill),
        Space::with_height(8),
    ]
    .spacing(0)
    .align_x(Alignment::Center)
    .width(Length::Fill)
    .height(Length::Fill)
    .padding(Padding { top: 28.0, bottom: 28.0, left: 32.0, right: 32.0 });

    // Contenedor principal: FROSTED GLASS (panel translúcido con blur visual)
    let panel = container(content)
        .width(Length::Shrink)
        .height(Length::Shrink)
        .style(move |_theme| {
            // Múltiples capas para efecto glass real
            let glass_bg = Color { a: 0.42, ..palette.surface_1 };
            let border = Border {
                color: palette.glass_border,
                width: 1.0,
                radius: 24.0.into(),
            };
            let shadow = Shadow {
                color: palette.glass_shadow,
                offset: Vector::new(0.0, 8.0),
                blur_radius: 32.0,
            };

            iced::widget::container::Style {
                background: Some(iced::Background::Color(glass_bg)),
                border,
                shadow,
                ..Default::default()
            }
        });

    // Ventana: fondo transparente real + panel centrado
    container(panel)
        .width(Length::Fill)
        .height(Length::Fill)
        .center(Length::Fill)
        .style(move |_theme| {
            iced::widget::container::Style {
                background: Some(iced::Background::Color(Color::TRANSPARENT)),
                ..Default::default()
            }
        })
        .into()
}

/// Configuración de la ventana (transparent, frameless, rounded).
fn window_settings() -> WindowSettings {
    WindowSettings {
        size: Size::new(520.0, 460.0),
        min_size: Some(Size::new(520.0, 460.0)),
        max_size: Some(Size::new(520.0, 460.0)),
        resizable: false,
        decorations: false,
        transparent: true,
        level: Level::AlwaysOnTop,
        position: window::Position::Centered,
        ..Default::default()
    }
}

fn main() -> iced::Result {
    let args: Vec<String> = std::env::args().collect();

    // Modo CLI
    if args.len() > 1 {
        let audio = AudioController::new();
        match args[1].as_str() {
            "--get" => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 { println!("Muted"); } else { println!("{} %", level); }
            }
            "--inc" => { if audio.get_status().1 { audio.toggle_mute(); } else { audio.increase(5); } }
            "--inc-precise" => { if audio.get_status().1 { audio.toggle_mute(); } else { audio.increase(1); } }
            "--dec" => { if audio.get_status().1 { audio.toggle_mute(); } else { audio.decrease(5); } }
            "--dec-precise" => { if audio.get_status().1 { audio.toggle_mute(); } else { audio.decrease(1); } }
            "--toggle" => { audio.toggle_mute(); }
            "--toggle-mic" => { let _ = std::process::Command::new("pamixer").arg("--default-source").arg("-t").status(); }
            "--get-icon" => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 { println!("volume-mute"); }
                else if level <= 30 { println!("volume-low"); }
                else if level <= 60 { println!("volume-mid"); }
                else { println!("volume-high"); }
            }
            _ => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 { println!("Muted"); } else { println!("{} %", level); }
            }
        }
        std::process::exit(0);
    }

    // Notificación
    let _ = std::process::Command::new("notify-send")
        .arg("-e").arg("-u").arg("low")
        .arg("Control de Volumen").arg("Ventana abierta")
        .status();

    // Modo GUI con animación de tick para spring
    application("Control de Volumen", update, view)
        .window(window_settings())
        .settings(Settings {
            default_text_size: 16.into(),
            antialiasing: true,
            ..Default::default()
        })
        .subscription(|_| time::every(Duration::from_millis(16)).map(Message::Tick))
        .run()
}