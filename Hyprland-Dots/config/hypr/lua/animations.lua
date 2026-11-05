-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Animaciones básicas (Hyprland 0.57+)
-- Mínimo funcional para evitar errores de config

-- Curvas estándar (copiadas del ejemplo oficial de Hyprland)
hl.curve("linear",   { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("quick",    { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",     { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- Animaciones mínimas activadas
hl.animation({ leaf = "global",    enabled = true, speed = 10,   bezier = "linear" })
hl.animation({ leaf = "windows",   enabled = true, speed = 5,    spring = "easy" })
hl.animation({ leaf = "workspaces",enabled = true, speed = 2,    bezier = "linear" })
