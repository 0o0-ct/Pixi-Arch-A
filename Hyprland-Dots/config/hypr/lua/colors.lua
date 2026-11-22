-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Paleta de colores y bordes dinámicos para Hyprland 0.57+ (Lua)
-- Lee los roles Material 3 generados por pixi_colors.py (Wallust -> Matugen)
-- desde ~/.config/quickshell/qml_color.json y aplica bordes en gradiente.
-- Si el archivo no existe, conserva el fallback ANSI anterior.

local home = os.getenv("HOME") or ""

-- ---------- paleta ANSI (fallback) ----------
local colors = {}
local conf_path = home .. "/.config/hypr/wallust/wallust-hyprland.conf"
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

local c15 = colors["color15"] or "rgba(e3e892ff)"
local c14 = colors["color14"] or "rgba(c7cc79ff)"
local c12 = colors["color12"] or "rgba(47482eff)"
local bg  = colors["background"] or "rgba(14140cff)"
local fg  = colors["foreground"] or "rgba(e5e3d6ff)"

-- ---------- roles Material 3 (fuente principal) ----------
-- pixi_colors.py es el único escritor: genera TODOS los roles M3 a partir del
-- fondo de pantalla. Hyprland solo los lee; nunca vuelve a extraer colores.
local m3 = {}
local qml_path = home .. "/.config/quickshell/qml_color.json"
local qf = io.open(qml_path, "r")
if qf then
    local content = qf:read("*a")
    qf:close()
    local block = content:match('"m3"%s*:%s*{(.-)}')
    if block then
        for key, hex in block:gmatch('"([%w_]+)"%s*:%s*"(#%x+)"') do
            m3[key] = hex
        end
    end
end

local function m3hex(key, fallback)
    local hex = m3[key]
    if not hex then return nil end
    return hex:gsub("^#", "")
end

local function m3rgba(key, fallback)
    local hex = m3hex(key, fallback)
    return hex and ("rgba(" .. hex .. "ff)") or fallback
end

local active1 = m3rgba("primary", c15)
local active2 = m3rgba("tertiary", c14)
local inactive = m3rgba("surface_container_low", c12)
local surface = m3rgba("surface", bg)

-- Configurar bordes y fondo con la paleta Material 3 del fondo de pantalla.
hl.config({
    general = {
        ["col.active_border"] = { colors = { active1, active2 }, angle = 45 },
        ["col.inactive_border"] = inactive,
    },
    misc = {
        background_color = surface,
    },
})

-- Exportar colores como variables de entorno de sesión
hl.env("PIXI_COLOR_ACTIVE_1", active1)
hl.env("PIXI_COLOR_ACTIVE_2", active2)
hl.env("PIXI_COLOR_INACTIVE", inactive)
hl.env("PIXI_COLOR_BG", surface)
hl.env("PIXI_COLOR_FG", m3rgba("on_surface", fg))
