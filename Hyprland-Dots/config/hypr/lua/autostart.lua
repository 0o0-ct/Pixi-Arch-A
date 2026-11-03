-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Aplicaciones que inician con Hyprland
-- Referencia: https://wiki.hypr.land/configuring/core/autostart/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    -- Script de arranque inicial (temas, wallpapers, marker file)
    hl.exec_cmd(home .. "/.config/hypr/initial-boot.sh")

    -- Daemons principales de la interfaz
    hl.exec_cmd("hypridle")
    hl.exec_cmd("bash -c 'command -v awww-daemon && exec awww-daemon; command -v swww-daemon && exec swww-daemon'")

    -- Quickshell overview
    hl.exec_cmd("command -v qs && qs -c overview")

    -- Thunar daemon para inicio instantáneo del explorador
    hl.exec_cmd("command -v thunar && thunar --daemon")

    -- Portapapeles (cliphist)
    hl.exec_cmd("command -v wl-paste && command -v cliphist && wl-paste --type text --watch cliphist store")
    hl.exec_cmd("command -v wl-paste && command -v cliphist && wl-paste --type image --watch cliphist store")

    -- Agente de autenticación Polkit
    hl.exec_cmd(scriptsDir .. "/Polkit.sh")

    -- Applets de red y bluetooth
    hl.exec_cmd("command -v nm-applet && nm-applet --indicator")
    hl.exec_cmd("command -v blueman-applet && blueman-applet")
    hl.exec_cmd("command -v kdeconnect-indicator && kdeconnect-indicator")

    -- Atajos y disposición de teclado inicial
    hl.exec_cmd("test -f " .. scriptsDir .. "/KeybindsLayoutInit.sh && " .. scriptsDir .. "/KeybindsLayoutInit.sh")

    -- Lanzar Refresh.sh (con Waybar, Wallust y temas sincronizados)
    hl.exec_cmd("sleep 0.5 && " .. scriptsDir .. "/Refresh.sh")
end)
