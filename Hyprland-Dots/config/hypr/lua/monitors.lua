-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Sistema Autónomo de Monitores y Resoluciones (Hyprland 0.57+ Lua)
-- Referencia: https://wiki.hypr.land/configuring/monitors/

-- =========================================================================
-- 1. REGLA AUTÓNOMA UNIVERSAL (CATCH-ALL)
-- =========================================================================
-- Autodetecta cualquier monitor conectado al iniciar o en caliente (hotplug):
-- - eDP-1 / eDP-2 (pantallas internas de laptop)
-- - HDMI-A-1 / HDMI-A-2 (puertos HDMI)
-- - DP-1 a DP-8 (DisplayPort en PC de escritorio o DisplayPort sobre USB-C / Thunderbolt)
-- - Virtual-1 (máquinas virtuales)
-- Utiliza 'highrr' para seleccionar la frecuencia nativa más alta sin limitar a 60Hz
-- y 'auto' para posicionarlos secuencialmente uno al lado del otro.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1.0,
})

-- =========================================================================
-- 2. SOPORTE DE PERSONALIZACIÓN Y PERFILES (nwg-displays / monitors.conf)
-- =========================================================================
-- Si el usuario define configuraciones manuales específicas en monitors.conf,
-- se cargan y se aplican sobre la regla universal sin anular el soporte hotplug.
local function load_custom_monitors()
    local home = os.getenv("HOME") or ""
    local conf_paths = {
        home .. "/.config/hypr/monitors.conf",
        home .. "/.config/hypr/UserConfigs/Monitors.conf",
    }

    for _, path in ipairs(conf_paths) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                local trimmed = line:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" and not trimmed:match("^#") then
                    local m = trimmed:match("^monitor%s*=%s*(.+)$")
                    if m then
                        local parts = {}
                        for part in m:gmatch("([^,]+)") do
                            table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        -- Si define un monitor específico (no la regla universal vacía)
                        if #parts >= 4 and parts[1] ~= "" and parts[1] ~= "," then
                            local out_name = parts[1]
                            local mode_val = parts[2]
                            local pos_val  = parts[3]
                            local scale_val = tonumber(parts[4]) or 1.0
                            hl.monitor({
                                output   = out_name,
                                mode     = mode_val,
                                position = pos_val,
                                scale    = scale_val,
                            })
                        end
                    end
                end
            end
            f:close()
            break
        end
    end
end

load_custom_monitors()
