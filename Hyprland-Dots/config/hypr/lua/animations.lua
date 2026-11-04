-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Animaciones y curvas (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/animations/

-- Definir curvas personalizadas
hl.curve("md3_decel", {
    control = {
        { x = 0.0, y = 0.0 },
        { x = 0.3, y = 0.3 },
        { x = 0.7, y = 0.7 },
        { x = 1.0, y = 1.0 },
    },
    bezier = true,
})

hl.curve("ease_out", {
    control = {
        { x = 0.0, y = 0.0 },
        { x = 0.3, y = 0.1 },
        { x = 0.7, y = 0.9 },
        { x = 1.0, y = 1.0 },
    },
    bezier = true,
})

hl.curve("ease_in", {
    control = {
        { x = 0.0, y = 0.0 },
        { x = 0.3, y = 0.1 },
        { x = 0.7, y = 0.5 },
        { x = 1.0, y = 1.0 },
    },
    bezier = true,
})

hl.curve("bounce", {
    control = {
        { x = 0.0, y = 0.0 },
        { x = 0.2, y = 0.3 },
        { x = 0.4, y = 0.1 },
        { x = 0.6, y = 0.7 },
        { x = 0.8, y = 0.2 },
        { x = 1.0, y = 1.0 },
    },
    bezier = true,
})

-- Configurar animaciones de ventanas
hl.config({
    animations = {
        windows = {
            -- Aparición/ desaparición
            new = {
                curve = "md3_decel",
                style = "popin 60%",
                speed = 10,
            },
            close = {
                curve = "ease_in",
                style = "collapse 30%",
                speed = 5,
            },
            -- Transiciones de estado
            maximize = { curve = "ease_out", style = "", speed = 5 },
            minimize = { curve = "ease_in", style = "", speed = 5 },
            fullscreen = { curve = "ease_out", style = "", speed = 8 },
            activate = { curve = "bounce", style = "", speed = 5 },
        },
    },
})
