//! CSS dinámico con hot-reload.
//!
//! Carga el CSS desde un archivo en disco (para permitir hot-reload)
//! o desde el CSS embebido como fallback, siempre precedido por la paleta
//! dinámica de wallust/matugen (`colors-waybar.css`), igual que glass-bt.

use gtk4::CssProvider;
use std::path::PathBuf;

/// Paleta de respaldo si no existe `colors-waybar.css`.
const FALLBACK_PALETTE: &str = "\
@define-color primary #b0c6ff;
@define-color on_primary #142f60;
@define-color primary_container #2e4578;
@define-color on_primary_container #d9e2ff;
@define-color secondary #bfc6dc;
@define-color tertiary #dfbbde;
@define-color surface #121318;
@define-color surface_container #1e1f25;
@define-color on_surface #e2e2e9;
@define-color foreground #e2e2e9;
@define-color color14 #b0c6ff;
@define-color color15 #d9e2ff;
";

/// Carga el CSS del tema (paleta + estilo), desde disco o embebido.
pub fn load_css(provider: &CssProvider) {
    let palette = std::fs::read_to_string(wallust_css_path())
        .unwrap_or_else(|_| FALLBACK_PALETTE.to_string());

    let base = resolve_css_path()
        .and_then(|p| std::fs::read_to_string(&p).ok())
        .unwrap_or_else(|| include_str!("../style.css").to_string());

    let css = format!("{palette}\n\n{base}");
    provider.load_from_data(&css);
    tracing::info!("CSS del tema cargado ({} bytes)", css.len());
}

/// Ruta de la paleta dinámica generada por wallust/matugen.
fn wallust_css_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(format!("{home}/.config/waybar/wallust/colors-waybar.css"))
}

/// Resuelve la ruta del archivo CSS en disco (hot-reload).
fn resolve_css_path() -> Option<PathBuf> {
    // 1. XDG config
    let config_home = std::env::var("XDG_CONFIG_HOME")
        .ok()
        .or_else(|| std::env::var("HOME").ok().map(|h| format!("{h}/.config")));

    if let Some(ch) = config_home {
        let p = PathBuf::from(format!("{ch}/glass-theme/style.css"));
        if p.exists() { return Some(p); }
    }

    // 2. Junto al ejecutable (dev: target/<profile>/../src/… ya no aplica; share/)
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
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
