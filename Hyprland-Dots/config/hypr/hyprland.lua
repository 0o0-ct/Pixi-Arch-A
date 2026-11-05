-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Archivo principal de configuración para Hyprland 0.57+ (Lua)
-- Referencia: https://wiki.hypr.land/configuring/

-- Ajustar package.path para cargar módulos locales en ~/.config/hypr/
local home = os.getenv("HOME") or ""
package.path = home .. "/.config/hypr/?.lua;" .. home .. "/.config/hypr/?/init.lua;" .. package.path

-- Carga modular de la configuración
require("lua.monitors")
require("lua.env")
require("lua.autostart")
require("lua.settings")
require("lua.decorations")
require("lua.animations")
require("lua.keybinds")
require("lua.rules")
require("lua.colors")
