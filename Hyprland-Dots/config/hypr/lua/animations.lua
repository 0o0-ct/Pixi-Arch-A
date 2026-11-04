-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Animaciones y curvas (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/animations/

-- Definir curvas personalizadas
hl.curve("md3_decel", {
    type = "bezier",
    points = {
        { 0.3, 0.3 },
        { 0.7, 0.7 },
    },
})

hl.curve("ease_out", {
    type = "bezier",
    points = {
        { 0.3, 0.1 },
        { 0.7, 0.9 },
    },
})

hl.curve("ease_in", {
    type = "bezier",
    points = {
        { 0.3, 0.1 },
        { 0.7, 0.5 },
    },
})

hl.curve("bounce", {
    type = "spring",
    damping = 12,
    stiffness = 60,
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
