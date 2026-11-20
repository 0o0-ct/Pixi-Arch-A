//! # glass-theme
//!
//! Tema compartido para las apps glass-* (glass-bt, glass-audio, etc.).
//! Proporciona tokens de diseño, CSS dinámico y widgets reutilizables
//! con el lenguaje visual One UI 8+ / glass (frosted glass, wallust/matugen).
//!
//! ## Uso
//! ```rust
//! use glass_theme::{Theme, load_css};
//! let css_provider = load_css();
//! ```

pub mod css;
pub mod tokens;
pub mod widgets;

/// Inicializa el tema GTK4 con el provider de CSS (hot-reload incluido).
pub fn init_theme() -> gtk4::CssProvider {
    css::init_theme()
}

/// Tokens de diseño reutilizables.
pub use tokens::*;
pub use widgets::*;