-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Variables de entorno y paths (Hyprland 0.57+)

local home = os.getenv("HOME") or ""
local configDir = home .. "/.config/hypr"
local scriptsDir = configDir .. "/scripts"
local userScripts = configDir .. "/UserScripts"

-- Exportar variables de entorno para usarse en scripts
os.setenv("HYPR_CONFIG_DIR", configDir)
os.setenv("HYPR_SCRIPTS_DIR", scriptsDir)
os.setenv("HYPR_USER_SCRIPTS_DIR", userScripts)

-- Linux containers y entornos especiales
local isContainer = os.getenv("container") ~= nil or
    os.getenv("container_name") ~= nil or
    os.getenv("container_id") ~= nil

if isContainer then
    os.setenv("HYPRLAND_INSTANCE_SIGNATURE", "pixi-arch-a-container")
end

-- Hacer accesible al usuario a través de los scripts
os.setenv("XDG_CONFIG_HOME", home .. "/.config")
