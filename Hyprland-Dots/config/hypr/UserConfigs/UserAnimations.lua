-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Preset: rápidas y directas
hl.animation({ leaf = "global",     enabled = true, speed = 10, bezier = "md3_decel" })
hl.animation({ leaf = "windows",    enabled = true, speed = 8,  bezier = "md3_decel" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 7,  bezier = "ease_out" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4,  bezier = "ease_in" })
hl.animation({ leaf = "layers",     enabled = true, speed = 6,  bezier = "md3_decel" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 4,  bezier = "ease_out" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 4,  bezier = "ease_in" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4,  bezier = "md3_decel", style = "slide" })
