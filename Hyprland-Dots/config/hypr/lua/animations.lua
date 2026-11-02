-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Animaciones: Configuración End-4 Fluida y Reactiva
-- Referencia: https://wiki.hypr.land/configuring/core/animations/

-- Definición de curvas Bézier (Material Design 3 & Fast decel)
hl.curve("md3_standard", 0.2, 0, 0, 1)
hl.curve("md3_decel", 0.05, 0.7, 0.1, 1)
hl.curve("md3_accel", 0.3, 0, 0.8, 0.15)
hl.curve("overshot", 0.05, 0.9, 0.1, 1.1)
hl.curve("crazyshot", 0.1, 1.5, 0.76, 0.92)
hl.curve("hyprnostyle", 0.28, 0.29, 0.42, 0.91)
hl.curve("menu_decel", 0.1, 1, 0, 1)
hl.curve("menu_accel", 0.38, 0.04, 1, 0.07)
hl.curve("easeInOutCirc", 0.85, 0, 0.15, 1)
hl.curve("easeOutCirc", 0, 0.55, 0.45, 1)
hl.curve("easeOutExpo", 0.16, 1, 0.3, 1)
hl.curve("softAcDecel", 0.16, 1, 0.3, 1)
hl.curve("quick", 0.15, 0, 0.1, 1)

-- Animaciones principales
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })
