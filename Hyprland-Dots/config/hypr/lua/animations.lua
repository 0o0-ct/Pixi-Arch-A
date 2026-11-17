-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Sistema modular de animaciones y curvas (Hyprland 0.57+ Lua)
-- Permite alternar presets en tiempo real con Animations.sh

local home = os.getenv("HOME") or ""

-- =========================================================================
-- CURVAS BEZIER Y RESORTES (SPRINGS)
-- =========================================================================
hl.curve("linear",      { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("quick",       { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("md3_decel",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("md3_accel",   { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("ease_in",     { type = "bezier", points = { {0.4, 0}, {1, 1} } })
hl.curve("ease_out",    { type = "bezier", points = { {0, 0}, {0.2, 1} } })
hl.curve("ease_in_out", { type = "bezier", points = { {0.4, 0}, {0.2, 1} } })
hl.curve("wind",        { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn",       { type = "bezier", points = { {0.1, 1.1}, {0.1, 1.1} } })
hl.curve("winOut",      { type = "bezier", points = { {0.3, -0.3}, {0, 1} } })
hl.curve("liner",       { type = "bezier", points = { {1, 1}, {1, 1} } })

-- Curvas elásticas de resorte
hl.curve("easy",        { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })
hl.curve("bounce",      { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- =========================================================================
-- CARGA DE PRESET ACTIVO O POR DEFECTO
-- =========================================================================
local user_anim = home .. "/.config/hypr/UserConfigs/UserAnimations.lua"
local default_anim = home .. "/.config/hypr/animations/00-default.lua"

local f_user = io.open(user_anim, "r")
if f_user then
    f_user:close()
    local ok, err = pcall(dofile, user_anim)
    if not ok then
        -- Fallback si el script del usuario tuvo error de sintaxis
        pcall(dofile, default_anim)
    end
else
    local f_def = io.open(default_anim, "r")
    if f_def then
        f_def:close()
        pcall(dofile, default_anim)
    else
        -- Fallback seguro integrado
        hl.animation({ leaf = "global",     enabled = true, speed = 10, bezier = "md3_decel" })
        hl.animation({ leaf = "windows",    enabled = true, speed = 5,  spring = "bounce" })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 5,  bezier = "md3_decel" })
    end
end
