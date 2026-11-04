-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Reglas de ventanas (window rules) (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/window-rules/

-- =========================================================================
-- APLICACIONES ESCOLARES Y EDICIÓN
-- =========================================================================
hl.window_rule({ match = { class = "jetbrains-studio" }, float = true, center = true })
hl.window_rule({ match = { class = "LibreOffice" }, float = true, layer = "top" })
hl.window_rule({ match = { class = "Gimp" }, float = true, center = true })

-- =========================================================================
-- NAVEGADORES Y INTERNET
-- =========================================================================
hl.window_rule({ match = { class = "firefox" }, float = false, layer = "background" })
hl.window_rule({ match = { class = "Chromium" }, float = false, layer = "background" })

-- =========================================================================
-- TERMINALES Y CONSOLAS
-- =========================================================================
hl.window_rule({ match = { class = "kitty" }, layer = "top", float = false })
hl.window_rule({ match = { class = "alacritty" }, layer = "top", float = false })
hl.window_rule({ match = { class = "wezterm" }, layer = "top", float = false })

-- =========================================================================
-- GESTIÓN DE VENTANAS ESPECIALES
-- =========================================================================
hl.window_rule({ match = { class = "dunst" }, float = true, center = true })
hl.window_rule({ match = { class = "swaync" }, float = true, center = true })
hl.window_rule({ match = { class = "xwayland" }, float = false, layer = "top" })

-- =========================================================================
-- FIKCIÓN (SPLIT) Y EMPAREJAMIENTO
-- =========================================================================
hl.window_rule({ match = { class = "kitty" }, float = false, layer = "top", size = "0.5 1" })
