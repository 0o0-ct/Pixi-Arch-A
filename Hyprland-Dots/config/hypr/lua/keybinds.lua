-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Atajos de teclado y ratón completos (Migración a Hyprland Lua)
-- Referencia: https://wiki.hypr.land/configuring/core/binds/
-- Referencia: https://wiki.hypr.land/configuring/core/dispatchers/

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"

local terminal = scriptsDir .. "/KittyRotate.sh"
local fileManager = "nautilus"

-- -------------------------------------------------------------------------
-- Helpers para binding
-- -------------------------------------------------------------------------
local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts or {})
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function moveWindow(workspace, follow)
    return hl.dsp.window.move({ workspace = workspace, follow = follow })
end

-- =========================================================================
-- 1. APLICACIONES BÁSICAS Y LANZADORES
-- =========================================================================
bind("SUPER + Return", exec(terminal), { description = "abrir terminal" })
bind("SUPER + D", exec("pkill rofi || true && rofi -show drun"), { description = "lanzador de aplicaciones" })
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
bind("SUPER + V", exec("qs -c controlcenter ipc call panel toggle"), { description = "panel flotante rapido" })
bind("SUPER + ALT + V", exec(scriptsDir .. "/ClipManager.sh"), { description = "administrador de portapapeles" })
bind("CTRL + SUPER + Space", exec(scriptsDir .. "/KeyboardLayout.sh switch"), { description = "cambiar teclado" })

-- Utilidades de escritorio
bind("SUPER + ALT + O", exec(scriptsDir .. "/ChangeBlur.sh"), { description = "alternar desenfoque" })
bind("SUPER + SHIFT + G", exec(scriptsDir .. "/GameMode.sh"), { description = "alternar modo de juego" })
bind("SUPER + ALT + L", exec(scriptsDir .. "/ChangeLayout.sh"), { description = "alternar diseno master/dwindle" })

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
bind("SUPER + ALT + B", exec(scriptsDir .. "/WaybarLayout.sh"), { description = "menu de diseno waybar" })

-- =========================================================================
-- 3. GESTIÓN DE VENTANAS Y ESTADOS (NATIVE DISPATCHERS)
-- =========================================================================
bind("SUPER + Q", hl.dsp.window.close(), { description = "cerrar ventana activa" })
bind("SUPER + SHIFT + Q", exec(scriptsDir .. "/KillActiveProcess.sh"), { description = "terminar proceso activo" })
bind("SUPER + Space", hl.dsp.window.float(), { description = "flotar ventana actual" })
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "pantalla completa" })
bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "maximizar ventana" })
bind("SUPER + P", hl.dsp.window.pseudo(), { description = "alternar pseudo dwindle" })
bind("SUPER + CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), { description = "alternar opacidad de ventana" })

-- Flotar todas las ventanas del espacio actual
bind("SUPER + ALT + Space", function()
    for _, win in ipairs(hl.get_windows()) do
        hl.dispatch(hl.dsp.window.float({ window = win, action = "on" }))
    end
end, { description = "flotar todas las ventanas" })

-- Movimiento de foco, ventanas, intercambio y redimensionado
local resize = {
    left  = { x = -50, y = 0 },
    right = { x = 50,  y = 0 },
    up    = { x = 0,   y = -50 },
    down  = { x = 0,   y = 50 },
}
local dirName = { left = "izquierda", right = "derecha", up = "arriba", down = "abajo" }
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }), { description = "enfocar " .. dirName[dir] })
    bind("SUPER + CTRL + " .. dir, hl.dsp.window.move({ direction = dir }), { description = "mover ventana " .. dirName[dir] })
    bind("SUPER + ALT + " .. dir, hl.dsp.window.swap({ direction = dir }), { description = "intercambiar ventana " .. dirName[dir] })
    bind("SUPER + SHIFT + " .. dir, hl.dsp.window.resize({
        x = resize[dir].x,
        y = resize[dir].y,
        relative = true,
    }), { description = "redimensionar " .. dirName[dir] })
end

-- Ciclar ventanas (reemplaza KeybindsLayoutInit.sh)
bind("SUPER + J", hl.dsp.window.cycle_next({ next = true }), { description = "siguiente ventana" })
bind("SUPER + K", hl.dsp.window.cycle_next({ next = false }), { description = "ventana anterior" })

-- =========================================================================
-- 4. ESPACIOS DE TRABAJO
-- =========================================================================
for i = 1, 10 do
    local key = i == 10 and "0" or tostring(i)
    bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(i) }), { description = "espacio " .. i })
    bind("SUPER + SHIFT + " .. key, moveWindow(tostring(i), true), { description = "mover a espacio " .. i })
    bind("SUPER + CTRL + " .. key, moveWindow(tostring(i), false), { description = "mover silencioso a espacio " .. i })
end

-- Espacios relativos y especiales
bind("SUPER + Tab", hl.dsp.focus({ workspace = "m+1" }), { description = "siguiente espacio" })
bind("SUPER + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }), { description = "espacio anterior" })
bind("SUPER + SHIFT + bracketleft", moveWindow("-1", true), { description = "mover a espacio anterior" })
bind("SUPER + SHIFT + bracketright", moveWindow("+1", true), { description = "mover a siguiente espacio" })
bind("SUPER + CTRL + bracketleft", moveWindow("-1", false), { description = "mover silencioso a espacio anterior" })
bind("SUPER + CTRL + bracketright", moveWindow("+1", false), { description = "mover silencioso a siguiente espacio" })
bind("SUPER + U", hl.dsp.workspace.toggle_special(), { description = "alternar espacio especial" })
bind("SUPER + SHIFT + U", moveWindow("special", true), { description = "mover a espacio especial" })

-- Scroll / teclas de navegación de espacios
hl.bind("SUPER + mouse:4", hl.dsp.focus({ workspace = "e+1" }), { description = "siguiente espacio" })
hl.bind("SUPER + mouse:5", hl.dsp.focus({ workspace = "e-1" }), { description = "espacio anterior" })
bind("SUPER + period", hl.dsp.focus({ workspace = "e+1" }), { description = "siguiente espacio" })
bind("SUPER + comma", hl.dsp.focus({ workspace = "e-1" }), { description = "espacio anterior" })

-- Mover espacio actual entre monitores
bind("SUPER + CTRL + F9", hl.dsp.workspace.move({ monitor = "l" }), { description = "mover espacio al monitor izquierdo" })
bind("SUPER + CTRL + F10", hl.dsp.workspace.move({ monitor = "r" }), { description = "mover espacio al monitor derecho" })
bind("SUPER + CTRL + F11", hl.dsp.workspace.move({ monitor = "u" }), { description = "mover espacio al monitor superior" })
bind("SUPER + CTRL + F12", hl.dsp.workspace.move({ monitor = "d" }), { description = "mover espacio al monitor inferior" })

-- =========================================================================
-- 5. GRUPOS DE VENTANAS
-- =========================================================================
bind("SUPER + G", hl.dsp.group.toggle(), { description = "alternar grupo" })
bind("SUPER + CTRL + Tab", hl.dsp.group.next(), { description = "siguiente ventana del grupo" })
bind("SUPER + CTRL + SHIFT + Tab", hl.dsp.group.prev(), { description = "ventana anterior del grupo" })
bind("SUPER + CTRL + K", hl.dsp.window.move({ into_group = "left" }), { description = "mover a la izquierda dentro del grupo" })
bind("SUPER + CTRL + L", hl.dsp.window.move({ into_group = "right" }), { description = "mover a la derecha dentro del grupo" })
bind("SUPER + CTRL + H", hl.dsp.window.move({ out_of_group = true }), { description = "sacar ventana del grupo" })

-- =========================================================================
-- 6. DISPOSICIÓN MASTER / DWINDLE
-- =========================================================================
bind("SUPER + CTRL + D", hl.dsp.layout("removemaster"), { description = "eliminar maestro" })
bind("SUPER + I", hl.dsp.layout("addmaster"), { description = "agregar maestro" })
bind("SUPER + CTRL + Return", hl.dsp.layout("swapwithmaster"), { description = "intercambiar con maestro" })
bind("SUPER + SHIFT + I", hl.dsp.layout("togglesplit"), { description = "alternar division dwindle" })
bind("SUPER + M", hl.dsp.layout("splitratio 0.3"), { description = "establecer proporcion de division a 0.3" })

-- =========================================================================
-- 7. RATÓN
-- =========================================================================
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "mover ventana con el raton" })
hl.bind("SUPER + mouse:3", hl.dsp.window.resize(), { drag = true, description = "redimensionar ventana con el raton" })
hl.bind("SUPER + ALT + mouse:4", hl.dsp.exec_cmd(scriptsDir .. "/Zoom.sh in"), { description = "acercar zoom" })
hl.bind("SUPER + ALT + mouse:5", hl.dsp.exec_cmd(scriptsDir .. "/Zoom.sh out"), { description = "alejar zoom" })

-- =========================================================================
-- 8. CAPTURAS DE PANTALLA
-- =========================================================================
bind("SUPER + Print", exec(scriptsDir .. "/ScreenShot.sh --now"), { description = "captura ahora" })
bind("SUPER + SHIFT + Print", exec(scriptsDir .. "/ScreenShot.sh --area"), { description = "captura area" })
bind("SUPER + CTRL + Print", exec(scriptsDir .. "/ScreenShot.sh --in5"), { description = "captura en 5s" })
bind("SUPER + CTRL + SHIFT + Print", exec(scriptsDir .. "/ScreenShot.sh --in10"), { description = "captura en 10s" })
bind("ALT + Print", exec(scriptsDir .. "/ScreenShot.sh --active"), { description = "captura ventana activa" })
bind("SUPER + SHIFT + S", exec(scriptsDir .. "/ScreenShot.sh --swappy"), { description = "captura con swappy" })

-- =========================================================================
-- 9. TECLAS MULTIMEDIA
-- =========================================================================
bind("XF86AudioRaiseVolume", exec(scriptsDir .. "/Volume.sh --inc"), { locked = true, repeating = true, description = "subir volumen" })
bind("XF86AudioLowerVolume", exec(scriptsDir .. "/Volume.sh --dec"), { locked = true, repeating = true, description = "bajar volumen" })
bind("ALT + XF86AudioRaiseVolume", exec(scriptsDir .. "/Volume.sh --inc-precise"), { locked = true, repeating = true, description = "subir volumen preciso" })
bind("ALT + XF86AudioLowerVolume", exec(scriptsDir .. "/Volume.sh --dec-precise"), { locked = true, repeating = true, description = "bajar volumen preciso" })
bind("XF86AudioMicMute", exec(scriptsDir .. "/Volume.sh --toggle-mic"), { locked = true, description = "silenciar microfono" })
bind("XF86AudioMute", exec(scriptsDir .. "/Volume.sh --toggle"), { locked = true, description = "silenciar audio" })
bind("XF86Sleep", exec("systemctl suspend"), { locked = true, description = "suspender" })
bind("XF86Rfkill", exec(scriptsDir .. "/AirplaneMode.sh"), { locked = true, description = "modo avion" })
bind("XF86AudioPause", exec(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "pausar" })
bind("XF86AudioPlay", exec(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "reproducir" })
bind("XF86AudioNext", exec(scriptsDir .. "/MediaCtrl.sh --nxt"), { locked = true, description = "siguiente pista" })
bind("XF86AudioPrev", exec(scriptsDir .. "/MediaCtrl.sh --prv"), { locked = true, description = "pista anterior" })
bind("XF86AudioStop", exec(scriptsDir .. "/MediaCtrl.sh --stop"), { locked = true, description = "detener" })

-- =========================================================================
-- 10. ENERGÍA, BLOQUEO Y SESIÓN
-- =========================================================================
bind("SUPER + L", exec(scriptsDir .. "/LockScreen.sh"), { description = "bloquear pantalla" })
bind("CTRL + ALT + L", exec(scriptsDir .. "/LockScreen.sh"), { description = "bloquear pantalla" })
bind("CTRL + ALT + P", exec(scriptsDir .. "/Wlogout.sh"), { description = "menu de energia" })
bind("CTRL + ALT + Delete", hl.dsp.exit(), { description = "salir de Hyprland" })

-- =========================================================================
-- 11. CICLAR VENTANAS CON ALT+TAB
-- =========================================================================
bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { description = "ciclar ventana siguiente" })

-- =========================================================================
-- 12. EVENTOS DE HYPRLAND
-- =========================================================================
-- Desactivado: al hacer 'hyprctl reload' no abrir el selector de temas
-- hl.on("config.reloaded", function()
--     hl.exec_cmd(scriptsDir .. "/ThemeChanger.sh reload")
-- end)
