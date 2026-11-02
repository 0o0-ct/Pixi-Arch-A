-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Helper para leer y exponer colores dinámicos de Wallust
local M = {}

local home = os.getenv("HOME") or ""
local wallust_conf = home .. "/.config/hypr/wallust/wallust-hyprland.conf"

-- Paleta por defecto (Dark fallback)
M.colors = {
    color0  = "rgba(1b1e20ff)",
    color1  = "rgba(d47779ff)",
    color2  = "rgba(81b29aff)",
    color3  = "rgba(f2cc8fff)",
    color4  = "rgba(7da0caff)",
    color5  = "rgba(b197fcff)",
    color6  = "rgba(85c1dcff)",
    color7  = "rgba(e0e0e0ff)",
    color8  = "rgba(595959aa)",
    color9  = "rgba(e06c75ff)",
    color10 = "rgba(98c379ff)",
    color11 = "rgba(e5c07bff)",
    color12 = "rgba(61afefff)",
    color13 = "rgba(c678ddff)",
    color14 = "rgba(56b6c2ff)",
    color15 = "rgba(ffffffcc)",
    active_border_1 = "rgba(33ccffee)",
    active_border_2 = "rgba(00ff99ee)",
}

local f = io.open(wallust_conf, "r")
if f then
    for line in f:lines() do
        local var, val = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
        if var and val then
            -- Convertir rgb(R,G,B) o rgb(HEX) o rgba(...)
            local hex = val:match("^rgb%((%x+)%)$")
            local hex_a = val:match("^rgba%((%x+)%)$")
            if hex then
                M.colors[var] = "0xff" .. hex
            elseif hex_a then
                M.colors[var] = "0x" .. hex_a
            else
                M.colors[var] = val
            end
        end
    end
    f:close()
    if M.colors.color15 and M.colors.color14 then
        M.colors.active_border_1 = M.colors.color15
        M.colors.active_border_2 = M.colors.color14
    end
end

return M
