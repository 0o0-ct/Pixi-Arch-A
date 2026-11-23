-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */

local home = os.getenv("HOME") or ""
local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts or {})
end
local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- SUPER+V pertenece exclusivamente al panel de QuickShell.
bind("SUPER + V", exec("qs -c controlcenter ipc call panel toggle"), { description = "panel rápido de QuickShell" })
-- El mezclador GTK nuevo se abre con SUPER+SHIFT+V.
bind("SUPER + SHIFT + V", exec(home .. "/.local/bin/glass-audio"), { description = "mezclador de audio glass" })
