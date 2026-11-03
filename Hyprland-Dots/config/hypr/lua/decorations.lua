-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Decoración: Cristal Esmerilado (Dark Frosted Glassmorphism)
-- Referencia: https://wiki.hypr.land/configuring/core/config-options/#decoration

local colors = require("lua.colors").colors

hl.config({
    general = {
        col = {
            active_border = {
                colors = { colors.active_border_1, colors.active_border_2 },
                angle = 45,
            },
            inactive_border = colors.color8 or "rgba(595959aa)",
        },
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1.0,

        dim_inactive = false,
        dim_strength = 0.1,
        dim_special = 0.8,

        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            ignore_opacity = true,
            new_optimizations = true,
            xray = false,
            noise = 0.0117,
            contrast = 0.90,
            brightness = 0.95,
            vibrancy = 0.20,
            vibrancy_darkness = 0.0,
            popups = true,
            popups_ignorealpha = 0.6,
        },

        shadow = {
            enabled = true,
            range = 14,
            render_power = 2,
            color = "rgba(00000066)",
        },
    },
})
