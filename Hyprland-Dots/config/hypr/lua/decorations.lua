-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Decoraciones, sombras y desenfoque (Hyprland 0.57+ Lua)
-- Valores optimizados para rendimiento (perfil balanced/performance)

hl.config({
    decoration = {
        -- Esquinas redondeadas estilo moderno
        rounding = 12,
        rounding_power = 2,

        -- Opacidades de ventana
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1.0,

        -- Sombras suaves (reducidas para rendimiento)
        shadow = {
            enabled = true,
            range = 4,
            render_power = 1,
            color = "rgba(00000020)",
            color_inactive = "rgba(00000010)",
        },

        -- Desenfoque (Blur) optimizado para bajo consumo
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            noise = 0.012,
            contrast = 0.85,
            brightness = 0.90,
            vibrancy = 0.0,
            xray = false,
            special = false,
            popups = false,
        },
    },
})
