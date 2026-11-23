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
    "bt-glass",
    "net-glass",
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
hl.window_rule({ match = { class = "com.pixi.glassbt" }, float = true, size = { 460, 640 }, center = true, border_size = 0, no_shadow = true })
hl.window_rule({ match = { class = "glass-bt" }, float = true, size = { 460, 640 }, center = true, border_size = 0, no_shadow = true })
hl.window_rule({ match = { class = "com.pixi.glassnet" }, float = true, size = { 460, 640 }, center = true, border_size = 0, no_shadow = true })
hl.window_rule({ match = { class = "com.pixi.glassaudio" }, float = true, size = { 720, 640 }, center = true, border_size = 0, no_shadow = true, rounding = 36 })
hl.window_rule({ match = { class = "glass-net" }, float = true, size = { 460, 640 }, center = true, border_size = 0, no_shadow = true })

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

-- Ahorro GPU: sin blur en ventanas (criterio de end-4 + wiki oficial).
-- Los layer surfaces (barra, dock, paneles) conservan su blur.
hl.window_rule({ match = { class = ".*" }, no_blur = true })

-- ── glass-audio: cristal translúcido (Hyprland 0.57+) ──────────────────────
-- La API Lua expone `no_blur` (no `blur`): false revierte la regla global de
-- ahorro GPU. Se declara DESPUÉS de esa regla para que gane por orden.
-- El CSS de la app usa fondos con alpha; el desenfoque lo aplica el compositor.
hl.window_rule({ match = { class = "com.pixi.glassaudio" }, no_blur = false, rounding = 36, border_size = 0, no_shadow = true })

-- Ventanas fijadas (pin=1): borde con el rol "primary" de Material 3,
-- extraído del fondo de pantalla por pixi_colors.py (estilo end-4).
local pinned_border = nil
local pinned_home = os.getenv("HOME") or ""
local pinned_file = io.open(pinned_home .. "/.config/quickshell/qml_color.json", "r")
if pinned_file then
    local pinned_content = pinned_file:read("*a")
    pinned_file:close()
    local primary = pinned_content:match('"primary"%s*:%s*"(#%x+)"')
    if primary then
        local hex = primary:gsub("^#", "")
        pinned_border = "rgba(" .. hex .. "aa) rgba(" .. hex .. "77)"
    end
end
if pinned_border then
    hl.window_rule({ match = { pin = 1 }, border_color = pinned_border })
end
