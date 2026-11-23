-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */

local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"
local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts or {})
end
local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end
local function moveWindow(workspace, follow)
    return hl.dsp.window.move({ workspace = workspace, follow = follow })
end

-- Atajos dedicados para los dos controles de sonido.
bind("SUPER + V", exec("volume-control"), { description = "control de volumen" })
bind("SUPER + SHIFT + V", exec("glass-audio"), { description = "mezclador de audio glass" })
