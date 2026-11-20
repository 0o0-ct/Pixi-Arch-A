//! # Control de Volumen - Pixi-Arch-A
//!
//! Control de volumen moderno en Rust + Iced, adaptado a la paleta de colores
//! del sistema (qml_color.json). Reemplaza la notificación vieja de swaync
//! por una ventana elegante y funcional.
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
    widget::{button, column, container, row, slider, text},
    application, Color, Element, Length, Alignment, Settings, Task, Theme, window::Settings as WindowSettings,
    Size,
};
use std::default::Default;

/// Paleta de colores basada en qml_color.json del sistema.
#[derive(Clone, Copy)]
pub struct Palette;

impl Palette {
    pub fn window_background(&self) -> Color {
        Color::from_rgb(0.098, 0.067, 0.078) // #191114
    }

    pub fn primary_text(&self) -> Color {
        Color::from_rgb(0.933, 0.875, 0.886) // #eedfe2
    }

    pub fn secondary_text(&self) -> Color {
        Color::from_rgb(0.835, 0.769, 0.776) // #d5c2c6
    }

    pub fn accent_primary(&self) -> Color {
        Color::from_rgb(1.0, 0.690, 0.800) // #ffb0cc
    }

    pub fn accent_secondary(&self) -> Color {
        Color::from_rgb(0.941, 0.737, 0.584) // #f0bc95
    }

    pub fn border_primary(&self) -> Color {
        Color::from_rgb(0.3181, 0.263, 0.278) // #514347
    }

    pub fn layer_background_1(&self) -> Color {
        Color::from_rgb(0.192, 0.157, 0.165) // #31282a
    }

    pub fn layer_background_2(&self) -> Color {
        Color::from_rgb(0.149, 0.114, 0.125) // #261d20
    }

    pub fn selection_background(&self) -> Color {
        Color::from_rgb(0.435, 0.200, 0.294) // #6f334b
    }
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
}

/// Controlador de audio (PipeWire vía pamixer).
struct AudioController;

impl AudioController {
    fn new() -> Self {
        Self
    }

    fn get_status(&self) -> (u32, bool) {
        if let Ok(out) = std::process::Command::new("pamixer")
            .arg("--get-volume")
            .output()
        {
            let level: u32 = String::from_utf8_lossy(&out.stdout)
                .trim()
                .parse()
                .unwrap_or(0);
            let muted_out = std::process::Command::new("pamixer")
                .arg("--get-mute")
                .output()
                .ok()
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or_else(|| "false".to_string());
            let muted = muted_out == "true" || level == 0;
            return (level, muted);
        }

        (0, false)
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

/// Widget principal de la aplicación.
struct VolumeControl {
    audio: AudioController,
    level: u32,
    muted: bool,
    status: Status,
}

impl Default for VolumeControl {
    fn default() -> Self {
        let audio = AudioController::new();
        let (level, muted) = audio.get_status();
        Self {
            audio,
            level,
            muted,
            status: if muted { Status::Muted } else { Status::Normal },
        }
    }
}

/// Actualiza el estado según el mensaje recibido.
fn update(state: &mut VolumeControl, message: Message) -> Task<Message> {
    match message {
        Message::VolumeChanged(value) => {
            state.level = value;
            if state.muted && value > 0 {
                state.muted = false;
                state.status = Status::Normal;
            }
            state.audio.set_volume(value);
            Task::none()
        }
        Message::ToggleMute => {
            state.audio.toggle_mute();
            state.muted = !state.muted;
            state.status = if state.muted {
                Status::Muted
            } else {
                Status::Normal
            };
            Task::none()
        }
        Message::Quit => std::process::exit(0),
    }
}

/// Renderiza la vista.
fn view(state: &VolumeControl) -> Element<'_, Message, Theme, iced::Renderer> {
    let p = Palette;

    // Icono de volumen según nivel y mute.
    let icon = if state.muted || state.level == 0 {
        "󰝟"
    } else if state.level <= 30 {
        "󰕿"
    } else if state.level <= 70 {
        "󰖀"
    } else {
        "󰕾"
    };

    let header = row![
        text(icon).size(32),
        column![
            text("Control de Volumen").size(18),
            text(if state.muted {
                "Silenciado"
            } else {
                "Volumen del sistema"
            })
            .size(14),
        ]
        .spacing(4)
        .align_x(Alignment::Start),
    ]
    .spacing(16)
    .align_y(Alignment::Center);

    let slider_value = state.level as f32;
    let volume_slider = slider(
        0.0..=150.0,
        slider_value,
        |v| Message::VolumeChanged(v as u32),
    )
    .width(Length::Fill)
    .style(move |_theme, _status| {
        iced::widget::slider::Style {
            rail: iced::widget::slider::Rail {
                backgrounds: (
                    iced::Background::Color(p.layer_background_2()),
                    iced::Background::Color(p.accent_primary()),
                ),
                width: 6.0,
                border: iced::Border {
                    width: 0.0,
                    color: iced::Color::TRANSPARENT,
                    radius: 0.0.into(),
                },
            },
            handle: iced::widget::slider::Handle {
                shape: iced::widget::slider::HandleShape::Circle { radius: 10.0 },
                background: iced::Background::Color(p.accent_primary()),
                border_width: 0.0,
                border_color: iced::Color::TRANSPARENT,
            },
        }
    });

    let percent = text(format!("{}%", state.level)).size(36)
        .style(move |_theme| {
            iced::widget::text::Style {
                color: Some(p.accent_primary()),
            }
        });

    let mute_button = button(text(if state.muted { "󰸈" } else { "󰝟" }).size(24))
        .padding(12)
        .on_press(Message::ToggleMute)
        .style(move |_theme, _status| {
            iced::widget::button::Style {
                background: Some(iced::Background::Color(if state.muted {
                    p.selection_background()
                } else {
                    p.layer_background_1()
                })),
                text_color: p.primary_text(),
                border: iced::Border {
                    color: p.border_primary(),
                    width: 1.0,
                    radius: 8.0.into(),
                },
                ..Default::default()
            }
        });

    let close_button = button(text("Cerrar").size(14))
        .padding(10)
        .on_press(Message::Quit)
        .style(move |_theme, _status| {
            iced::widget::button::Style {
                background: Some(iced::Background::Color(p.layer_background_2())),
                text_color: p.secondary_text(),
                border: iced::Border {
                    color: p.border_primary(),
                    width: 1.0,
                    radius: 8.0.into(),
                },
                ..Default::default()
            }
        });

    let controls = row![mute_button, close_button]
        .spacing(12)
        .align_y(Alignment::Center)
        .width(Length::Fill);

    let content = column![
        header,
        container(volume_slider).padding(20).width(Length::Fill),
        row![percent].align_y(Alignment::Center).width(Length::Fill),
        container(controls).padding(20).width(Length::Fill),
    ]
    .spacing(10)
    .align_x(Alignment::Center)
    .width(Length::Fill)
    .height(Length::Fill)
    .padding(24);

    container(content)
        .width(Length::Fill)
        .height(Length::Fill)
        .style(move |_theme| {
            iced::widget::container::Style {
                background: Some(iced::Background::Color(p.layer_background_1())),
                text_color: Some(p.primary_text()),
                border: iced::Border {
                    color: p.accent_primary(),
                    width: 3.0,
                    radius: 16.0.into(),
                },
                ..Default::default()
            }
        })
        .into()
}

fn main() -> iced::Result {
    // Modo CLI: si se pasan argumentos, actuar como Volume.sh
    let args: Vec<String> = std::env::args().collect();

    if args.len() > 1 {
        let audio = AudioController::new();
        match args[1].as_str() {
            "--get" => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 {
                    println!("Muted");
                } else {
                    println!("{} %", level);
                }
            }
            "--inc" => {
                if audio.get_status().1 {
                    audio.toggle_mute();
                } else {
                    audio.increase(5);
                }
            }
            "--inc-precise" => {
                if audio.get_status().1 {
                    audio.toggle_mute();
                } else {
                    audio.increase(1);
                }
            }
            "--dec" => {
                if audio.get_status().1 {
                    audio.toggle_mute();
                } else {
                    audio.decrease(5);
                }
            }
            "--dec-precise" => {
                if audio.get_status().1 {
                    audio.toggle_mute();
                } else {
                    audio.decrease(1);
                }
            }
            "--toggle" => {
                audio.toggle_mute();
            }
            "--toggle-mic" => {
                let _ = std::process::Command::new("pamixer").arg("--default-source").arg("-t").status();
            }
            "--get-icon" => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 {
                    println!("volume-mute");
                } else if level <= 30 {
                    println!("volume-low");
                } else if level <= 60 {
                    println!("volume-mid");
                } else {
                    println!("volume-high");
                }
            }
            _ => {
                let (level, muted) = audio.get_status();
                if muted || level == 0 {
                    println!("Muted");
                } else {
                    println!("{} %", level);
                }
            }
        }
        std::process::exit(0);
    }

    // Notificar al usuario que se abrió el control de volumen
    let _ = std::process::Command::new("notify-send")
        .arg("-e")
        .arg("-u")
        .arg("low")
        .arg("Control de Volumen")
        .arg("Ventana abierta")
        .status();

    // Modo GUI: mostrar la ventana de control de volumen
    application("Control de Volumen", update, view)
        .window(WindowSettings {
            size: Size::new(500.0, 420.0),
            min_size: Some(Size::new(500.0, 420.0)),
            resizable: false,
            decorations: true,
            transparent: false,
            ..Default::default()
        })
        .settings(Settings {
            default_text_size: 16.into(),
            antialiasing: true,
            ..Default::default()
        })
        .run()
}