-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Parche temporal para binds de ratón (Hyprland 0.57+)
-- Los binds de ratón usan mouse:1 (izquierdo) y mouse:3 (derecho)
-- en lugar de mouse:272 y mouse:273 que no funcionan en Lua API

-- Mover ventana con el ratón: SUPER + clic izquierdo
-- Redimensionar ventana con el ratón: SUPER + clic derecho

hl.bind("SUPER + mouse:1", hl.dsp.window.move(), { drag = true, description = "mover ventana con el raton" })
hl.bind("SUPER + mouse:3", hl.dsp.window.resize(), { drag = true, description = "redimensionar ventana con el raton" })

hl.bind("SUPER + ALT + mouse_down", hl.dsp.exec_cmd("~/.config/hypr/scripts/Zoom.sh in"), { description = "acercar zoom" })
hl.bind("SUPER + ALT + mouse_up", hl.dsp.exec_cmd("~/.config/hypr/scripts/Zoom.sh out"), { description = "alejar zoom" })
