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

        -- Vibrancy y transparencia
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fading = true,
        fade_duration = 0.4,
        opacity_step = 0.02,

        -- Resaltado de ventana activa
        active_window_border = {
            size = 2,
            color = "#FF4136FF",
            style = "solid"
        },
        inactive_window_border = {
            size = 1,
            color = "#FF413633",
            style = "solid"
        },

        -- Efectos de ventana
        shadow = {
            size = 12,
            h_offset = 0,
            v_offset = 4,
            blur = 16,
            color = "#00000088"
        },
        rounded_corners = {
            enable = true,
            size = 10,
            bottom = false,
        },

        -- Layer rules
        layer = {
            tooltip = { blur = false },
            draggable_message = { blur = false },
            combined = { blur = false },
            wallpaper = { blur = false },
            ghost = { blur = false },
            overlay = { blur = false },
        },
    },
})
