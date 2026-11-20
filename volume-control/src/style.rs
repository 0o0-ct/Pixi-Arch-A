use iced::Color;

/// Paleta de colores basada en qml_color.json del sistema.
/// Usamos los mismos valores que el tema "dark" de Quickshell.
pub struct Palette;

impl Palette {
    pub fn name() -> &'static str {
        "custom"
    }

    pub fn window_background(&self) -> Color {
        Color::from_rgb(0x19, 0x11, 0x14)
    }

    pub fn primary_text(&self) -> Color {
        Color::from_rgb(0xee, 0xdf, 0xe2)
    }

    pub fn secondary_text(&self) -> Color {
        Color::from_rgb(0xd5, 0xc4, 0xc6)
    }

    pub fn accent_primary(&self) -> Color {
        Color::from_rgb(0xff, 0xb0, 0xcc)
    }

    pub fn accent_secondary(&self) -> Color {
        Color::from_rgb(0xf0, 0xbc, 0x95)
    }

    pub fn border_primary(&self) -> Color {
        Color::from_rgb(0x51, 0x43, 0x47)
    }

    pub fn layer_background_1(&self) -> Color {
        Color::from_rgb(0x31, 0x28, 0x2a)
    }

    pub fn layer_background_2(&self) -> Color {
        Color::from_rgb(0x26, 0x1d, 0x20)
    }

    pub fn selection_background(&self) -> Color {
        Color::from_rgb(0x6f, 0x33, 0x4b)
    }

    pub fn primary(&self) -> Color {
        self.accent_primary()
    }

    pub fn secondary(&self) -> Color {
        self.accent_secondary()
    }

    pub fn accent_primary_text(&self) -> Color {
        Color::from_rgb(0x54, 0x1d, 0x35)
    }
}

impl iced::Theme for Palette {
    type Executor = iced::executor::Default;
    type Message = ();

    fn tag(&self) -> String {
        "volume_control".to_string()
    }

    fn appearance(&self) -> iced::Appearance {
        iced::Appearance {
            background: self.window_background(),
            ..Default::default()
        }
    }
}