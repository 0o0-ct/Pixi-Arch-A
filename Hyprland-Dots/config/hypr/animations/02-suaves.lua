-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Preset: suaves y lentas
hl.animation({ leaf = "global",     enabled = true, speed = 4, bezier = "ease_out" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "ease_out" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3, bezier = "ease_out", style = "slidefade" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "ease_in",  style = "slidefade" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3, bezier = "ease_out" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2, bezier = "ease_out" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2, bezier = "ease_in" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "ease_out", style = "fade" })
