//! CSS dinámico con hot-reload.
//!
//! Carga el CSS desde un archivo en disco (para permitir hot-reload)
//! o desde el CSS embebido como fallback.

use gtk4::CssProvider;
use std::path::PathBuf;

/// Carga el CSS del tema. Primero intenta desde disco (para hot-reload),
/// luego desde el CSS embebido.
pub fn load_css(provider: &CssProvider) {
    // Intentar cargar desde disco para hot-reload
    if let Some(path) = resolve_css_path() {
        provider.load_from_path(&path);
        tracing::info!("CSS cargado desde: {}", path.display());
        return;
    }

    // Fallback: CSS embebido
    let css = include_str!("../style.css");
    provider.load_from_data(css);
    tracing::info!("CSS cargado desde recurso embebido");
}

/// Resuelve la ruta del archivo CSS en disco.
fn resolve_css_path() -> Option<PathBuf> {
    // 1. XDG config
    let config_home = std::env::var("XDG_CONFIG_HOME")
        .ok()
        .or_else(|| std::env::var("HOME").ok().map(|h| format!("{h}/.config")));

    if let Some(ch) = config_home {
        let p = PathBuf::from(format!("{ch}/glass-theme/style.css"));
        if p.exists() { return Some(p); }
    }

    // 2. Junto al ejecutable
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let dev_css = dir.join("../src/style.css");
            if dev_css.exists() { return Some(dev_css); }
            let share_css = dir.join("../share/glass-theme/style.css");
            if share_css.exists() { return Some(share_css); }
        }
    }

    // 3. Home local
    if let Ok(home) = std::env::var("HOME") {
        let p = PathBuf::from(format!("{home}/.local/share/glass-theme/style.css"));
        if p.exists() { return Some(p); }
    }

    None
}

/// Inicializa el tema GTK4 con el provider de CSS.
pub fn init_theme() -> CssProvider {
    let provider = CssProvider::new();
    load_css(&provider);

    if let Some(display) = gtk4::gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }

    provider
}