-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Reglas de ventana (window rules) y capas (layer rules)
-- Referencia: https://wiki.hypr.land/configuring/core/rules/

-- Regla general: Android Studio y asistentes JetBrains centrados y flotantes
hl.window_rule({
    match = { class = "^(jetbrains-studio.*)$" },
    float = true,
    center = true,
})

-- GNOME Files (Nautilus) macOS Tahoe Glass Rules
hl.window_rule({
    match = { class = "^(org\\.gnome\\.Nautilus)$" },
    float = true,
    size = { 1100, 700 },
    center = true,
    opacity = { 0.92, 0.88 },
    rounding = 16,
})

-- Picture-in-Picture (PiP para Firefox, Chrome, etc.)
hl.window_rule({
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
})

-- Ventanas flotantes por defecto (diálogos, visores, preferencias)
local float_classes = {
    "^([Pp]avucontrol)$",
    "^([Bb]lueman-manager)$",
    "^([Nn]m-connection-editor)$",
    "^([Kk]vantummanager)$",
    "^([Qq]t5ct)$",
    "^([Qq]t6ct)$",
    "^([Gg]nome-disks)$",
    "^(nwg-look)$",
    "^(swappy)$",
    "^(yad)$",
    "^(zenity)$",
    "^(file-roller)$",
    "^(org\\.gnome\\.FileRoller)$",
}

for _, cls in ipairs(float_classes) do
    hl.window_rule({
        match = { class = cls },
        float = true,
    })
end

-- Diálogos modales y confirmaciones (Nautilus y gestores de archivos)
hl.window_rule({
    match = { title = "^(Open File|Save File|Confirm to replace files|File Operation Progress|Extract archive|Compress)$" },
    float = true,
    center = true,
})

-- Reglas para capas (Blur y orden en elementos de la interfaz)
local blurred_layers = {
    "waybar",
    "rofi",
    "wlogout",
    "swaync-control-center",
    "swaync-notification-window",
    "quickshell:overview",
    "quickshell:audiocenter",
    "quickshell:btcenter",
    "quickshell:controlcenter",
    "quickshell:netcenter",
}

for _, lyr in ipairs(blurred_layers) do
    hl.layer_rule({
        match = { namespace = lyr },
        blur = true,
        ignore_alpha = 0.5,
    })
end
