-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Atajos de teclado y ratón
-- Referencia: https://wiki.hypr.land/configuring/core/binds/
-- Referencia de dispatchers: https://wiki.hypr.land/configuring/core/dispatchers/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"

local terminal = "kitty"
local fileManager = "thunar"

-- Aplicaciones básicas y gestión de ventanas
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal Kitty" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "Gestor de archivos Thunar" })
hl.bind("SUPER + D", hl.dsp.exec_cmd("rofi -show drun -modi drun,filebrowser,run,window"), { description = "Lanzador de aplicaciones (drun)" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Cerrar ventana activa con graceful request" })
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.kill(), { description = "Forzar cierre (kill -9) de ventana activa" })
hl.bind("SUPER + Space", hl.dsp.window.float(), { description = "Alternar ventana flotante" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Alternar pantalla completa" })
hl.bind("SUPER + P", hl.dsp.window.pseudo(), { description = "Dwindle pseudo" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Alternar división de ventana" })

-- Scripts y utilidades Pixi-Arch-A
hl.bind("SUPER + S", hl.dsp.exec_cmd(scriptsDir .. "/RofiSearch.sh"), { description = "Búsqueda web con Rofi" })
hl.bind("SUPER + L", hl.dsp.exec_cmd(scriptsDir .. "/LockScreen.sh"), { description = "Bloquear pantalla" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(scriptsDir .. "/Wlogout.sh"), { description = "Menú de salida" })
hl.bind("SUPER + V", hl.dsp.exec_cmd(scriptsDir .. "/ClipManager.sh"), { description = "Gestor de portapapeles" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(scriptsDir .. "/WallustSwww.sh"), { description = "Ciclador de wallpaper y tema" })
hl.bind("SUPER + R", hl.dsp.exec_cmd(scriptsDir .. "/Refresh.sh"), { description = "Refrescar interfaz y Waybar" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(scriptsDir .. "/OverviewToggle.sh"), { description = "Vista general de ventanas" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(scriptsDir .. "/NetworkMenu.sh"), { description = "Menú de red Wi-Fi" })
hl.bind("SUPER + Period", hl.dsp.exec_cmd(scriptsDir .. "/RofiEmoji.sh"), { description = "Selector de emojis" })
hl.bind("SUPER + H", hl.dsp.exec_cmd(scriptsDir .. "/KeyHints.sh"), { description = "Ayuda de atajos de teclado" })
hl.bind("CTRL + SUPER + Space", hl.dsp.exec_cmd(scriptsDir .. "/KeyboardLayout.sh switch"), { description = "Cambiar distribución de teclado" })
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd(scriptsDir .. "/GameMode.sh"), { description = "Modo juego" })

-- Capturas de pantalla
hl.bind("Print", hl.dsp.exec_cmd(scriptsDir .. "/ScreenShot.sh --now"), { description = "Captura completa" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd(scriptsDir .. "/ScreenShot.sh --area"), { description = "Captura de área" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(scriptsDir .. "/ScreenShot.sh --area"), { description = "Captura de área (Snip)" })

-- Control de volumen y brillo (teclas multimedia sin modificador, locked para responder en lockscreen)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --inc"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --dec"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle-mic"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scriptsDir .. "/Brightness.sh --inc"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scriptsDir .. "/Brightness.sh --dec"), { locked = true })

-- Navegación de foco entre ventanas (flechas)
hl.bind("SUPER + Left", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "d" }))

-- Mover ventanas en el tiling
hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

-- Espacios de trabajo (Workspaces 1 a 10)
for i = 1, 10 do
    local key = tostring(i % 10)
    local ws = tostring(i)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws, follow = true }))
    hl.bind("SUPER + CTRL + " .. key, hl.dsp.window.move({ workspace = ws, follow = false }))
end

-- Espacio de trabajo especial (Scratchpad)
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- Atajos con ratón (mover y redimensionar arrastrando)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
