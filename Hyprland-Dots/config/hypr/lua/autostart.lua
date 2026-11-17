-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Autostart (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/autostart/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"

-- Arranque idempotente de daemons de sesión (portapapeles, swww, hypridle,
-- waybar, polkit, hyprsunset). StartupApps.sh comprueba procesos antes de
-- lanzarlos, así que es seguro ejecutarlo en cada inicio.
hl.on("hyprland.start", function()
    hl.exec_cmd(scriptsDir .. "/StartupApps.sh")
end)
