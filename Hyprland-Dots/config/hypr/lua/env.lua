-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Variables de entorno y paths (Hyprland 0.57+)

local home = os.getenv("HOME") or ""
local configDir = home .. "/.config/hypr"
local scriptsDir = configDir .. "/scripts"
local userScripts = configDir .. "/UserScripts"

-- Exportar variables de entorno para usarse en scripts
hl.env("HYPR_CONFIG_DIR", configDir)
hl.env("HYPR_SCRIPTS_DIR", scriptsDir)
hl.env("HYPR_USER_SCRIPTS_DIR", userScripts)

-- Linux containers y entornos especiales
local isContainer = os.getenv("container") ~= nil or
    os.getenv("container_name") ~= nil or
    os.getenv("container_id") ~= nil

if isContainer then
    hl.env("HYPRLAND_INSTANCE_SIGNATURE", "pixi-arch-a-container")
end

-- Hacer accesible al usuario a través de los scripts
hl.env("XDG_CONFIG_HOME", home .. "/.config")
