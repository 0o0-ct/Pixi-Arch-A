-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Atajos de teclado y ratón completos (Migración a Hyprland Lua)
-- Referencias:
-- https://wiki.hypr.land/configuring/core/binds/
-- https://wiki.hypr.land/configuring/core/dispatchers/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"

local terminal = scriptsDir .. "/KittyRotate.sh"
local fileManager = "nautilus"

-- -------------------------------------------------------------------------
-- Helper functions para binding
-- -------------------------------------------------------------------------
local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts or {})
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- =========================================================================
-- 1. APLICACIONES BÁSICAS Y LANZADORES
-- =========================================================================
bind("SUPER + Return", exec(terminal), { description = "abrir terminal" })
bind("SUPER + D", exec("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"), { description = "lanzador de aplicaciones" })
bind("SUPER + B", exec('xdg-open "https://"'), { description = "abrir navegador predeterminado" })
bind("SUPER + E", exec(fileManager), { description = "administrador de archivos" })
bind("SUPER + A", exec(scriptsDir .. "/OverviewToggle.sh"), { description = "vista general del escritorio" })
bind("SUPER + SHIFT + Return", exec(scriptsDir .. "/Dropterminal.sh " .. terminal), { description = "terminal desplegable" })

-- Búsquedas, utilidades y menús
bind("SUPER + S", exec(scriptsDir .. "/RofiSearch.sh"), { description = "busqueda web" })
bind("SUPER + CTRL + S", exec("rofi -show window"), { description = "selector de ventanas" })
bind("SUPER + ALT + E", exec(scriptsDir .. "/RofiEmoji.sh"), { description = "menu de emojis" })
bind("SUPER + ALT + C", exec(userScripts .. "/RofiCalc.sh"), { description = "calculadora" })
bind("SUPER + H", exec(scriptsDir .. "/KeyHints.sh"), { description = "ayuda y atajos" })
bind("SUPER + SHIFT + K", exec(scriptsDir .. "/KeyBinds.sh"), { description = "buscar atajos" })
bind("SUPER + SHIFT + E", exec(scriptsDir .. "/Kool_Quick_Settings.sh"), { description = "menu de ajustes rapidos" })
bind("SUPER + SHIFT + N", exec("qs -c controlcenter ipc call panel toggle"), { description = "panel de control" })
bind("SUPER + N", exec(scriptsDir .. "/Hyprsunset.sh toggle"), { description = "alternar luz nocturna" })
bind("SUPER + V", exec("ags -t 'floating-panel'"), { description = "panel flotante rapido" })
bind("SUPER + ALT + V", exec(scriptsDir .. "/ClipManager.sh"), { description = "administrador de portapapeles" })
bind("CTRL + SUPER + Space", exec(scriptsDir .. "/KeyboardLayout.sh switch"), { description = "cambiar teclado" })

-- =========================================================================
-- 2. TEMAS, FONDOS Y WAYBAR
-- =========================================================================
bind("SUPER + T", exec(scriptsDir .. "/ThemeChanger.sh"), { description = "selector de tema global Wallust" })
bind("SUPER + W", exec(userScripts .. "/WallpaperSelect.sh"), { description = "seleccionar fondo" })
bind("SUPER + SHIFT + W", exec(userScripts .. "/WallpaperEffects.sh"), { description = "efectos de fondo" })
bind("CTRL + ALT + W", exec(userScripts .. "/WallpaperRandom.sh"), { description = "fondo aleatorio" })
bind("SUPER + SHIFT + A", exec(scriptsDir .. "/Animations.sh"), { description = "menu de animaciones" })
bind("SUPER + SHIFT + O", exec(userScripts .. "/ZshChangeTheme.sh"), { description = "cambiar tema de terminal zsh" })
bind("SUPER + SHIFT + M", exec(userScripts .. "/RofiBeats.sh"), { description = "musica en linea" })
bind("SUPER + CTRL + R", exec(scriptsDir .. "/RofiThemeSelector.sh"), { description = "selector de temas de rofi" })
bind("SUPER + CTRL + SHIFT + R", exec("pkill rofi || true && " .. scriptsDir .. "/RofiThemeSelector-modified.sh"), { description = "selector de temas de rofi modificado" })

-- Waybar
bind("SUPER + ALT + R", exec(scriptsDir .. "/Refresh.sh"), { description = "recargar barra y menus" })
bind("SUPER + R", exec(scriptsDir .. "/Refresh.sh"), { description = "recargar barra y menus" })
bind("SUPER + CTRL + ALT + B", exec("pkill -SIGUSR1 waybar"), { description = "alternar waybar" })
bind("SUPER + CTRL + B", exec(scriptsDir .. "/WaybarStyles.sh"), { description = "menu de estilos waybar" })
bind("SUPER + ALT + B", exec(scriptsDir .. "/WaybarLayout.sh"), { description = "menu de diseño waybar" })

-- =========================================================================
-- 3. GESTIÓN DE VENTANAS Y ESTADOS
-- =========================================================================
bind("SUPER + Q", hl.dsp.window.close(), { description = "cerrar ventana activa" })
bind("SUPER + SHIFT + Q", exec(scriptsDir .. "/KillActiveProcess.sh"), { description = "terminar proceso activo" })
bind("SUPER + Space", hl.dsp.window.float(), { description = "flotar ventana actual" })
bind("SUPER + ALT + Space", exec("hyprctl dispatch workspaceopt allfloat"), { description = "flotar todas las ventanas" })
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "pantalla completa" })
bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "maximizar ventana" })
bind("SUPER + P", hl.dsp.window.pseudo(), { description = "alternar pseudo dwindle" })
bind("ALT + Tab", exec("hyprctl dispatch cyclenext"), { description = "ciclar ventana siguiente" })

-- Opciones de sistema y efectos
bind("SUPER + ALT + O", exec(scriptsDir .. "/ChangeBlur.sh"), { description = "alternar desenfoque" })
bind("SUPER + CTRL + O", exec("hyprctl setprop active opaque toggle"), { description = "alternar opacidad de ventana" })
bind("SUPER + SHIFT + G", exec(scriptsDir .. "/GameMode.sh"), { description = "alternar modo de juego" })

-- Sesión y bloqueo
bind("SUPER + L", exec(scriptsDir .. "/LockScreen.sh"), { description = "bloquear pantalla" })
bind("CTRL + ALT + L", exec(scriptsDir .. "/LockScreen.sh"), { description = "bloquear pantalla" })
bind("CTRL + ALT + P", exec(scriptsDir .. "/Wlogout.sh"), { description = "menu de energia" })
bind("SUPER + Escape", exec(scriptsDir .. "/Wlogout.sh"), { description = "menu de salida" })
bind("CTRL + ALT + Delete", exec("hyprctl dispatch exit 0"), { description = "salir de Hyprland" })

-- =========================================================================
-- 4. DISEÑOS (MASTER & DWINDLE)
-- =========================================================================
bind("SUPER + ALT + L", exec(scriptsDir .. "/ChangeLayout.sh"), { description = "alternar diseño master/dwindle" })
bind("SUPER + CTRL + D", exec("hyprctl dispatch layoutmsg removemaster"), { description = "eliminar master" })
bind("SUPER + I", exec("hyprctl dispatch layoutmsg addmaster"), { description = "agregar master" })
bind("SUPER + CTRL + Return", exec("hyprctl dispatch layoutmsg swapwithmaster"), { description = "intercambiar con master" })
bind("SUPER + SHIFT + I", exec("hyprctl dispatch layoutmsg togglesplit"), { description = "alternar division dwindle" })
bind("SUPER + J", exec("hyprctl dispatch layoutmsg togglesplit"), { description = "alternar division dwindle" })
bind("SUPER + M", exec("hyprctl dispatch splitratio 0.3"), { description = "establecer proporcion de division a 0.3" })

-- =========================================================================
-- 5. GRUPOS DE VENTANAS
-- =========================================================================
bind("SUPER + G", exec("hyprctl dispatch togglegroup"), { description = "alternar grupo" })
bind("SUPER + CTRL + Tab", exec("hyprctl dispatch changegroupactive f"), { description = "siguiente en grupo" })
bind("SUPER + CTRL + SHIFT + Tab", exec("hyprctl dispatch changegroupactive b"), { description = "anterior en grupo" })
bind("SUPER + CTRL + K", exec("hyprctl dispatch moveintogroup l"), { description = "mover a la izq dentro del grupo" })
bind("SUPER + CTRL + L", exec("hyprctl dispatch moveintogroup r"), { description = "mover a la der dentro del grupo" })
bind("SUPER + CTRL + H", exec("hyprctl dispatch moveoutofgroup"), { description = "sacar activa del grupo" })

-- =========================================================================
-- 6. NAVEGACIÓN, MOVIMIENTO, REDIMENSIONADO E INTERCAMBIO
-- =========================================================================
-- Foco (movefocus)
bind("SUPER + Left", exec("hyprctl dispatch movefocus l"), { description = "enfocar izq" })
bind("SUPER + Right", exec("hyprctl dispatch movefocus r"), { description = "enfocar der" })
bind("SUPER + Up", exec("hyprctl dispatch movefocus u"), { description = "enfocar arr" })
bind("SUPER + Down", exec("hyprctl dispatch movefocus d"), { description = "enfocar aba" })

-- Mover ventanas (movewindow)
bind("SUPER + CTRL + Left", exec("hyprctl dispatch movewindow l"), { description = "mover ventana izq" })
bind("SUPER + CTRL + Right", exec("hyprctl dispatch movewindow r"), { description = "mover ventana der" })
bind("SUPER + CTRL + Up", exec("hyprctl dispatch movewindow u"), { description = "mover ventana arr" })
bind("SUPER + CTRL + Down", exec("hyprctl dispatch movewindow d"), { description = "mover ventana aba" })

-- Redimensionar ventanas activas (resizeactive)
bind("SUPER + SHIFT + Left", exec("hyprctl dispatch resizeactive -50 0"), { description = "redimensionar izq (-50)", repeat_rate = true })
bind("SUPER + SHIFT + Right", exec("hyprctl dispatch resizeactive 50 0"), { description = "redimensionar der (+50)", repeat_rate = true })
bind("SUPER + SHIFT + Up", exec("hyprctl dispatch resizeactive 0 -50"), { description = "redimensionar arr (-50)", repeat_rate = true })
bind("SUPER + SHIFT + Down", exec("hyprctl dispatch resizeactive 0 50"), { description = "redimensionar aba (+50)", repeat_rate = true })

-- Intercambiar ventanas (swapwindow)
bind("SUPER + ALT + Left", exec("hyprctl dispatch swapwindow l"), { description = "intercambiar ventana izq" })
bind("SUPER + ALT + Right", exec("hyprctl dispatch swapwindow r"), { description = "intercambiar ventana der" })
bind("SUPER + ALT + Up", exec("hyprctl dispatch swapwindow u"), { description = "intercambiar ventana arr" })
bind("SUPER + ALT + Down", exec("hyprctl dispatch swapwindow d"), { description = "intercambiar ventana aba" })

-- =========================================================================
-- 7. ESPACIOS DE TRABAJO (WORKSPACES)
-- =========================================================================
-- Navegación relativa
bind("SUPER + Tab", exec("hyprctl dispatch workspace m+1"), { description = "siguiente espacio" })
bind("SUPER + SHIFT + Tab", exec("hyprctl dispatch workspace m-1"), { description = "espacio anterior" })
bind("SUPER + Period", exec("hyprctl dispatch workspace e+1"), { description = "siguiente espacio" })
bind("SUPER + Comma", exec("hyprctl dispatch workspace e-1"), { description = "espacio anterior" })
bind("SUPER + mouse_down", exec("hyprctl dispatch workspace e+1"), { description = "siguiente espacio" })
bind("SUPER + mouse_up", exec("hyprctl dispatch workspace e-1"), { description = "espacio anterior" })

-- Espacio de trabajo especial (Scratchpad)
bind("SUPER + U", exec("hyprctl dispatch togglespecialworkspace"), { description = "alternar espacio especial" })
bind("SUPER + SHIFT + U", exec("hyprctl dispatch movetoworkspace special"), { description = "mover a espacio especial" })

-- Desplazamiento de ventanas a espacios anterior/siguiente con brackets [ y ]
bind("SUPER + SHIFT + bracketleft", exec("hyprctl dispatch movetoworkspace -1"), { description = "mover a espacio anterior" })
bind("SUPER + SHIFT + bracketright", exec("hyprctl dispatch movetoworkspace +1"), { description = "mover a siguiente espacio" })
bind("SUPER + CTRL + bracketleft", exec("hyprctl dispatch movetoworkspacesilent -1"), { description = "mover silencioso a espacio anterior" })
bind("SUPER + CTRL + bracketright", exec("hyprctl dispatch movetoworkspacesilent +1"), { description = "mover silencioso a siguiente espacio" })

-- Espacios numéricos 1 a 10 (con teclas normales y keycodes 10 a 19 para soporte multinacional)
for i = 1, 10 do
    local key = tostring(i % 10)
    local ws = tostring(i)
    local code = tostring(9 + i) -- 10 = key 1, ..., 19 = key 0

    -- Ir a espacio de trabajo
    bind("SUPER + " .. key, exec("hyprctl dispatch workspace " .. ws), { description = "espacio " .. ws })
    bind("SUPER + code:" .. code, exec("hyprctl dispatch workspace " .. ws), { description = "espacio " .. ws })

    -- Mover ventana activa y seguir
    bind("SUPER + SHIFT + " .. key, exec("hyprctl dispatch movetoworkspace " .. ws), { description = "mover a espacio " .. ws })
    bind("SUPER + SHIFT + code:" .. code, exec("hyprctl dispatch movetoworkspace " .. ws), { description = "mover a espacio " .. ws })

    -- Mover ventana activa en silencio
    bind("SUPER + CTRL + " .. key, exec("hyprctl dispatch movetoworkspacesilent " .. ws), { description = "mover silencioso a espacio " .. ws })
    bind("SUPER + CTRL + code:" .. code, exec("hyprctl dispatch movetoworkspacesilent " .. ws), { description = "mover silencioso a espacio " .. ws })
end

-- Mover espacio de trabajo entre monitores
bind("SUPER + CTRL + F9", exec("hyprctl dispatch movecurrentworkspacetomonitor l"), { description = "mover espacio al monitor izq" })
bind("SUPER + CTRL + F10", exec("hyprctl dispatch movecurrentworkspacetomonitor r"), { description = "mover espacio al monitor der" })
bind("SUPER + CTRL + F11", exec("hyprctl dispatch movecurrentworkspacetomonitor u"), { description = "mover espacio al monitor arr" })
bind("SUPER + CTRL + F12", exec("hyprctl dispatch movecurrentworkspacetomonitor d"), { description = "mover espacio al monitor aba" })

-- =========================================================================
-- 8. CAPTURAS DE PANTALLA
-- =========================================================================
bind("Print", exec(scriptsDir .. "/ScreenShot.sh --now"), { description = "captura ahora" })
bind("SUPER + Print", exec(scriptsDir .. "/ScreenShot.sh --now"), { description = "captura ahora" })
bind("SUPER + SHIFT + Print", exec(scriptsDir .. "/ScreenShot.sh --area"), { description = "captura area" })
bind("SUPER + SHIFT + S", exec(scriptsDir .. "/ScreenShot.sh --swappy"), { description = "captura swappy" })
bind("SUPER + CTRL + Print", exec(scriptsDir .. "/ScreenShot.sh --in5"), { description = "captura en 5s" })
bind("SUPER + CTRL + SHIFT + Print", exec(scriptsDir .. "/ScreenShot.sh --in10"), { description = "captura en 10s" })
bind("ALT + Print", exec(scriptsDir .. "/ScreenShot.sh --active"), { description = "captura ventana activa" })

-- Capturas alternativas mediante tecla F6 (útil para portátiles sin PrintScreen)
bind("SUPER + F6", exec(scriptsDir .. "/ScreenShot.sh --now"), { description = "captura ahora (F6)" })
bind("SUPER + SHIFT + F6", exec(scriptsDir .. "/ScreenShot.sh --area"), { description = "captura area (F6)" })
bind("SUPER + CTRL + F6", exec(scriptsDir .. "/ScreenShot.sh --in5"), { description = "captura en 5s (F6)" })
bind("SUPER + ALT + F6", exec(scriptsDir .. "/ScreenShot.sh --in10"), { description = "captura en 10s (F6)" })
bind("ALT + F6", exec(scriptsDir .. "/ScreenShot.sh --active"), { description = "captura ventana activa (F6)" })

-- =========================================================================
-- 9. CONTROL DE AUDIO Y MEDIOS (TECLAS MULTIMEDIA)
-- =========================================================================
bind("XF86AudioRaiseVolume", exec(scriptsDir .. "/Volume.sh --inc"), { locked = true, repeat_rate = true, description = "subir volumen" })
bind("XF86AudioLowerVolume", exec(scriptsDir .. "/Volume.sh --dec"), { locked = true, repeat_rate = true, description = "bajar volumen" })
bind("ALT + XF86AudioRaiseVolume", exec(scriptsDir .. "/Volume.sh --inc-precise"), { locked = true, repeat_rate = true, description = "subir volumen preciso" })
bind("ALT + XF86AudioLowerVolume", exec(scriptsDir .. "/Volume.sh --dec-precise"), { locked = true, repeat_rate = true, description = "bajar volumen preciso" })
bind("XF86AudioMute", exec(scriptsDir .. "/Volume.sh --toggle"), { locked = true, description = "silenciar audio" })
bind("XF86AudioMicMute", exec(scriptsDir .. "/Volume.sh --toggle-mic"), { locked = true, description = "silenciar micrófono" })

bind("XF86AudioPlayPause", exec(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "reproducir/pausar" })
bind("XF86AudioPause", exec(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "pausar" })
bind("XF86AudioPlay", exec(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "reproducir" })
bind("XF86AudioNext", exec(scriptsDir .. "/MediaCtrl.sh --nxt"), { locked = true, description = "siguiente pista" })
bind("XF86AudioPrev", exec(scriptsDir .. "/MediaCtrl.sh --prv"), { locked = true, description = "pista anterior" })
bind("XF86AudioStop", exec(scriptsDir .. "/MediaCtrl.sh --stop"), { locked = true, description = "detener" })

bind("XF86Sleep", exec("systemctl suspend"), { locked = true, description = "suspender" })
bind("XF86Rfkill", exec(scriptsDir .. "/AirplaneMode.sh"), { locked = true, description = "modo avión" })

-- =========================================================================
-- 10. TECLAS ESPECÍFICAS DE PORTÁTILES (BRILLO, TECLADO, VENTILADORES)
-- =========================================================================
bind("XF86MonBrightnessDown", exec(scriptsDir .. "/Brightness.sh --dec"), { locked = true, repeat_rate = true, description = "bajar brillo monitor" })
bind("XF86MonBrightnessUp", exec(scriptsDir .. "/Brightness.sh --inc"), { locked = true, repeat_rate = true, description = "subir brillo monitor" })
bind("XF86KbdBrightnessDown", exec(scriptsDir .. "/BrightnessKbd.sh --dec"), { locked = true, repeat_rate = true, description = "bajar brillo teclado" })
bind("XF86KbdBrightnessUp", exec(scriptsDir .. "/BrightnessKbd.sh --inc"), { locked = true, repeat_rate = true, description = "subir brillo teclado" })
bind("XF86TouchpadToggle", exec(scriptsDir .. "/TouchPad.sh"), { description = "alternar touchpad" })

-- Teclas Asus ROG / TUF
bind("XF86Launch1", exec("rog-control-center"), { description = "ASUS Armory Crate / ROG Control Center" })
bind("XF86Launch3", exec("asusctl led-mode -n"), { description = "ASUS perfil RGB de teclado" })
bind("XF86Launch4", exec("asusctl profile -n"), { description = "ASUS perfil de ventilador" })

-- Teclas Acer NitroSense
bind("XF86Launch7", exec("damx"), { description = "Acer NitroSense (DAMX)" })
bind("XF86LaunchA", exec("damx"), { description = "Acer NitroSense variante (DAMX)" })

-- =========================================================================
-- 11. RATÓN Y MAGNIFICADOR (ZOOM)
-- =========================================================================
bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "mover ventana" })
bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "redimensionar ventana" })

-- Magnificador de escritorio (zoom factor)
-- Magnificador de escritorio (zoom factor) usando función Lua nativa
bind("SUPER + ALT + mouse_down", function()
    local current = 1.0
    if hl.get_config and hl.get_config("cursor.zoom_factor") then
        current = tonumber(hl.get_config("cursor.zoom_factor")) or 1.0
    end
    local new_factor = math.min(current * 1.5, 5.0)
    hl.config({ cursor = { zoom_factor = new_factor } })
end, { description = "acercar zoom" })

bind("SUPER + ALT + mouse_up", function()
    local current = 1.0
    if hl.get_config and hl.get_config("cursor.zoom_factor") then
        current = tonumber(hl.get_config("cursor.zoom_factor")) or 1.0
    end
    local new_factor = math.max(current / 1.5, 1.0)
    hl.config({ cursor = { zoom_factor = new_factor } })
end, { description = "alejar zoom" })
