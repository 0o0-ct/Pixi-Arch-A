-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Autostart (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/autostart/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"

-- Ejecutar scripts de autostart
hl.on("hyprland.start", function()
    -- Menú de bienvenida / inicio
    hl.exec_cmd(scriptsDir .. "/StartupMenu.sh")

    -- Notificaciones de inicio
    hl.exec_cmd("notify-send -i " .. scriptsDir .. "/assets/logo.png " .. scriptsDir .. "/StartupMenu.sh")

    -- Mostrar que Hyprland está listo
    hl.exec_cmd("hyprctl keyword general:style_show_fps 0")
end)
