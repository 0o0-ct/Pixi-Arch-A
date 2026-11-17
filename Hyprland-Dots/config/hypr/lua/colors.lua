-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Paleta de colores y bordes dinámicos para Hyprland 0.57+ (Lua)
-- Lee la paleta generada por Wallust / Matugen y aplica bordes en gradiente

local home = os.getenv("HOME") or ""
local conf_path = home .. "/.config/hypr/wallust/wallust-hyprland.conf"

local colors = {}
local f = io.open(conf_path, "r")
if f then
    for line in f:lines() do
        local var, hex = line:match("^%$([%w_]+)%s*=%s*rgb%((%x+)%)")
        if var and hex then
            colors[var] = "rgba(" .. hex .. "ff)"
        end
    end
    f:close()
end

-- Colores con fallbacks seguros
local c15 = colors["color15"] or "rgba(e3e892ff)"
local c14 = colors["color14"] or "rgba(c7cc79ff)"
local c12 = colors["color12"] or "rgba(47482eff)"
local bg  = colors["background"] or "rgba(14140cff)"
local fg  = colors["foreground"] or "rgba(e5e3d6ff)"

-- Configurar bordes de ventanas con degradado dinámico Material 3
hl.config({
    general = {
        ["col.active_border"] = { colors = { c15, c14 }, angle = 45 },
        ["col.inactive_border"] = c12,
    },
})

-- Exportar colores como variables de entorno de sesión
hl.env("PIXI_COLOR_ACTIVE_1", c15)
hl.env("PIXI_COLOR_ACTIVE_2", c14)
hl.env("PIXI_COLOR_INACTIVE", c12)
hl.env("PIXI_COLOR_BG", bg)
hl.env("PIXI_COLOR_FG", fg)
