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

local function dispatch(dispatcher, args)
    return hl.dsp.dispatch(dispatcher, args or {})
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
bind("SUPER + CTRL + S", dispatch("windowmenu"), { description = "selector de ventanas" })
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
-- 3. GESTIÓN DE VENTANAS Y ESTADOS (NATIVE DISPATCHERS)
-- =========================================================================
bind("SUPER + Q", hl.dsp.window.close(), { description = "cerrar ventana activa" })
bind("SUPER + SHIFT + Q", exec(scriptsDir .. "/KillActiveProcess.sh"), { description = "terminar proceso activo" })
bind("SUPER + Space", hl.dsp.window.float(), { description = "flotar ventana actual" })
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "pantalla completa" })
bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "maximizar ventana" })
bind("SUPER + P", hl.dsp.window.pseudo(), { description = "alternar pseudo dwindle" })
bind("ALT + Tab", hl.dsp.window.cycle_next(), { description = "ciclar ventana siguiente" })

-- =========================================================================
-- 4. OTRAS ACCIÓNES ÚTILES
-- =========================================================================
bind("SUPER + ALT + L", exec(scriptsDir .. "/LockScreen.sh"), { description = "bloqueo de pantalla" })
bind("SUPER + CTRL + O", exec(scriptsDir .. "/OverviewToggle.sh"), { description = "vista general del escritorio (overlay)" })
bind("SUPER + SHIFT + E", exec(scriptsDir .. "/Kool_Quick_Settings.sh"), { description = "menu de ajustes rapidos" })

-- =========================================================================
-- 5. EVENTOS DE HIPRRLAND (ENLACES ESPECIALES)
-- =========================================================================
hl.on("hyprland.start", function()
    hl.exec_cmd(scriptsDir .. "/StartupApps.sh")
end)

hl.on("hyprland.configure", function()
    hl.exec_cmd(scriptsDir .. "/ThemeChanger.sh reload")
end)
