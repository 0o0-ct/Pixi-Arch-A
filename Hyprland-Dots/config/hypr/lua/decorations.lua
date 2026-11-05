-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Decoraciones básicas (Hyprland 0.57+)
-- Mínimo funcional para evitar errores de config

hl.config({
    decoration = {
        -- Blur básico (claves validadas en 0.57)
        blur = {
            enabled   = true,
            size      = 8,
            passes    = 1,
            noise     = 0.0,
            contrast  = 1.0,
            brightness = 1.0,
            vibrancy  = 0.0,
            xray      = false,
        },

        -- Transparencia
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Esquinas redondeadas
        rounding        = 10,
        rounding_power  = 2,
    },
})
