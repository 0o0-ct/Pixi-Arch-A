-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Preset: pop-in marcado
hl.animation({ leaf = "global",     enabled = true, speed = 10, bezier = "md3_decel" })
hl.animation({ leaf = "windows",    enabled = true, speed = 6,  spring = "bounce" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 6,  spring = "bounce", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3,  bezier = "ease_in", style = "popin 40%" })
hl.animation({ leaf = "layers",     enabled = true, speed = 5,  bezier = "ease_out" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3,  bezier = "ease_out" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3,  bezier = "ease_in" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4,  bezier = "ease_out", style = "slidefade" })
