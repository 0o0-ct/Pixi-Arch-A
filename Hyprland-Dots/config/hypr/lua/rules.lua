-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Reglas de ventanas (window rules) (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/window-rules/

-- =========================================================================
-- APLICACIONES ESCOLARES Y EDICIÓN
-- =========================================================================
hl.window_rule({ match = { class = "jetbrains-studio" }, float = true, center = true })
hl.window_rule({ match = { class = "LibreOffice" }, float = true })
hl.window_rule({ match = { class = "Gimp" }, float = true, center = true })

-- =========================================================================
-- NAVEGADORES Y INTERNET
-- =========================================================================
hl.window_rule({ match = { class = "firefox" }, float = false })
hl.window_rule({ match = { class = "Chromium" }, float = false })

-- =========================================================================
-- TERMINALES Y CONSOLAS
-- =========================================================================
hl.window_rule({ match = { class = "kitty" }, float = false })
hl.window_rule({ match = { class = "alacritty" }, float = false })
hl.window_rule({ match = { class = "wezterm" }, float = false })

-- =========================================================================
-- GESTIÓN DE VENTANAS ESPECIALES
-- =========================================================================
hl.window_rule({ match = { class = "dunst" }, float = true, center = true })
hl.window_rule({ match = { class = "swaync" }, float = true, center = true })
hl.window_rule({ match = { class = "xwayland" }, float = false })
