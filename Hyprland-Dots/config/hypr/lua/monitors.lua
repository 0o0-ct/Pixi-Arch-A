-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Monitores y resoluciones (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/monitor/

-- Configurar monitores con scale correcto para evitar exceso de zoom
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@165",
    position = "0x0",
    scale    = 1.0,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "1920x0",
    scale    = 1,
})
