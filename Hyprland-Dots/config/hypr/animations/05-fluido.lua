-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Preset: fluido con resortes
hl.animation({ leaf = "global",     enabled = true, speed = 10,   spring = "bounce" })
hl.animation({ leaf = "windows",    enabled = true, speed = 5.5,  spring = "bounce" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 5,    spring = "bounce", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5,  bezier = "ease_in", style = "slide" })
hl.animation({ leaf = "layers",     enabled = true, speed = 4.5,  spring = "bounce" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.5,  bezier = "ease_out" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2.5,  bezier = "ease_in" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3,    spring = "bounce", style = "slidevert" })
