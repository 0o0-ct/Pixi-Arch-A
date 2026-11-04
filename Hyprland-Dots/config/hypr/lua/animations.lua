-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Animaciones y curvas (Hyprland 0.57+)
-- Referencia: https://wiki.hypr.land/configuring/core/animations/

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
    mass = 1,
    damping = 12,
    stiffness = 60,
})

-- Configurar animaciones de ventanas (estilo Hyprland 0.57)
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "md3_decel" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "bounce" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "bounce", style = "popin 60%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "ease_in",  style = "collapse 30%" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "ease_out" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "ease_out" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "ease_in" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "ease_out", style = "fade" })
