-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Decoraciones, sombras y desenfoque (Hyprland 0.57+ Lua)
-- Valores optimizados del perfil balanceado Pixi-Arch-A

hl.config({
    decoration = {
        -- Esquinas redondeadas estilo moderno
        rounding = 14,
        rounding_power = 2,

        -- Opacidades de ventana
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1.0,

        -- Sombras suaves
        shadow = {
            enabled = true,
            range = 12,
            render_power = 2,
            color = "rgba(00000030)",
            color_inactive = "rgba(00000015)",
        },

        -- Desenfoque (Blur) optimizado
        blur = {
            enabled = true,
            size = 8,
            passes = 1,
            noise = 0.012,
            contrast = 0.90,
            brightness = 0.95,
            vibrancy = 0.0,
            xray = false,
            special = true,
            popups = true,
        },
    },
})
