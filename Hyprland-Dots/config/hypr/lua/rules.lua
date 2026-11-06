-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Reglas de ventanas y capas (Window & Layer Rules) (Hyprland 0.57+ Lua)
-- Referencia: https://wiki.hypr.land/configuring/window-rules/

-- =========================================================================
-- REGLAS DE CAPAS (Frosted Glassmorphism Layer Rules)
-- =========================================================================
local glass_layers = {
    "waybar",
    "rofi",
    "swaync",
    "gtk-layer-shell",
    "quickshell-controlcenter",
    "quickshell-netcenter",
    "quickshell-btcenter",
    "quickshell-audiocenter",
    "quickshell:overview",
    "logout_dialog",
}

for _, ns in ipairs(glass_layers) do
    hl.layer_rule({ match = { namespace = ns }, blur = true, ignore_alpha = 0.1 })
end

-- =========================================================================
-- REGLAS DE VENTANAS FLOTANTES Y UTILIDADES
-- =========================================================================
-- Gestores de archivos y ventanas estilo macOS Tahoe
hl.window_rule({ match = { class = "org.gnome.Nautilus" }, float = true, size = { 1100, 700 }, center = true, opacity = 0.95 })
hl.window_rule({ match = { class = "nautilus" }, float = true, size = { 1100, 700 }, center = true, opacity = 0.95 })
hl.window_rule({ match = { class = "thunar" }, float = true, size = { 1000, 650 }, center = true })

-- Controles de audio y conexiones
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, float = true, size = { 800, 550 }, center = true })
hl.window_rule({ match = { class = "pavucontrol" }, float = true, size = { 800, 550 }, center = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true, center = true })
hl.window_rule({ match = { class = "blueman-manager" }, float = true, size = { 750, 520 }, center = true, opacity = "0.88 0.78" })

-- Diálogos y visores
hl.window_rule({ match = { class = "feh" }, float = true, center = true })
hl.window_rule({ match = { class = "mpv" }, float = true, center = true })
hl.window_rule({ match = { class = "eog" }, float = true, center = true })

-- Aplicaciones profesionales y de desarrollo
hl.window_rule({ match = { class = "jetbrains-studio" }, float = true, center = true })
hl.window_rule({ match = { class = "LibreOffice" }, float = true })
hl.window_rule({ match = { class = "Gimp" }, float = true, center = true })

-- Notificaciones y daemons
hl.window_rule({ match = { class = "dunst" }, float = true, center = true })
hl.window_rule({ match = { class = "swaync" }, float = true, center = true })

-- =========================================================================
-- APLICACIONES EN MOSAICO (TILED)
-- =========================================================================
hl.window_rule({ match = { class = "firefox" }, float = false })
hl.window_rule({ match = { class = "Chromium" }, float = false })
hl.window_rule({ match = { class = "kitty" }, float = false })
hl.window_rule({ match = { class = "alacritty" }, float = false })
hl.window_rule({ match = { class = "wezterm" }, float = false })
hl.window_rule({ match = { class = "xwayland" }, float = false })
