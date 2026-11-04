-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Decoraciones de ventanas (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/decoration/

hl.config({
    decoration = {
        -- General de decoraciones
        blur = {
            size = 8,
            passes = 1,
            noise = 0.0,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.0,
            vibrancy_darkness = 0.5,
            new_optimizations = true,
            xray = false,
            ignore_opacity = true,
            popups = false,
            popups_ignorealpha = 0.2,
            special = false,
        },

        -- Transparencia de ventanas
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        -- Sombras
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = 0x00000088,
            offset = 4,
        },

        -- Esquinas redondeadas
        rounding = 10,
        rounding_power = 2,
    },
})
