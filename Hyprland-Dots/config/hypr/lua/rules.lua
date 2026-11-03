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
    opacity = "0.92 0.88",
    rounding = 16,
})

-- =========================================================================
-- REGLAS DE TRANSPARENCIA Y OPACIDAD DE APLICACIONES (Window Opacities)
-- =========================================================================

-- Terminales (Kitty, Alacritty): ligera transparencia para lucir el fondo
hl.window_rule({
    match = { class = "^(Alacritty|kitty|kitty-dropterm)$" },
    opacity = "0.90 0.70",
})

-- Editores de código y proyectos (VS Code, Codium, JetBrains, Zed)
hl.window_rule({
    match = { class = "^(VSCode|code|code-url-handler|codium|codium-url-handler|VSCodium|jetbrains-.+|dev\\.zed\\.Zed|antigravity)$" },
    opacity = "0.90 0.80",
})

-- Gestores de archivos (Thunar, Pcmanfm-qt, Warp)
hl.window_rule({
    match = { class = "^([Tt]hunar|[Pp]cmanfm-qt|app\\.drey\\.Warp)$" },
    opacity = "0.90 0.80",
})

-- Navegadores web (Firefox, Chrome, Brave, Zen, Edge, Chromium)
hl.window_rule({
    match = { class = "^([Ff]irefox|org\\.mozilla\\.firefox|[Ff]irefox-esr|[Ff]irefox-bin|[Gg]oogle-chrome.*|chrome-.*|[Cc]hromium|[Mm]icrosoft-edge.*|Brave-browser.*|[Tt]horium-browser|[Cc]achy-browser|zen-alpha|zen)$" },
    opacity = "0.99 0.80",
})

-- Mensajería y Redes (Discord, WebCord, Vesktop, Telegram, WhatsApp, Teams, Element)
hl.window_rule({
    match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop|[Ff]erdium|[Ww]hatsapp-for-linux|org\\.telegram\\.desktop|io\\.github\\.tdesktop_x64\\.TDesktop|teams-for-linux|im\\.riot\\.Riot|Element)$" },
    opacity = "0.94 0.86",
})

-- Clientes de correo (Thunderbird, Betterbird, Evolution)
hl.window_rule({
    match = { class = "^([Tt]hunderbird|org\\.mozilla\\.Thunderbird|eu\\.betterbird\\.Betterbird|org\\.gnome\\.Evolution)$" },
    opacity = "0.94 0.86",
})

-- Ajustes del sistema, diálogos y herramientas (Pavucontrol, Blueman, Qt/Kvantum, Rofi, Disks)
hl.window_rule({
    match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|com\\.saivert\\.pwvucontrol|nm-applet|nm-connection-editor|blueman-manager|qt5ct|qt6ct|nwg-look|nwg-displays|btrfs-assistant|timeshift-gtk|baobab|org\\.gnome\\.[Bb]aobab|gnome-disks|wihotspot.*)$" },
    opacity = "0.80 0.70",
})

-- Editores de texto ligeros (Mousepad, Gedit, GNOME TextEditor)
hl.window_rule({
    match = { class = "^(gedit|org\\.gnome\\.TextEditor|mousepad)$" },
    opacity = "0.80 0.70",
})

-- Visores de sistema y documentos (GNOME System Monitor, Mission Center, Evince, Loupe, Eog)
hl.window_rule({
    match = { class = "^(gnome-system-monitor|org\\.gnome\\.SystemMonitor|io\\.missioncenter\\.MissionCenter|evince|eog|org\\.gnome\\.Loupe)$" },
    opacity = "0.82 0.75",
})

-- Clientes Torrent / Descargas y Bóveda (Deluge, Seahorse)
hl.window_rule({
    match = { class = "^(deluge|seahorse)$" },
    opacity = "0.90 0.80",
})

-- Reproductores de video (Mpv, VLC): Opacidad 1.0 fija (sin transparencia para no arruinar películas)
hl.window_rule({
    match = { class = "^([Mm]pv|vlc)$" },
    opacity = "1.0 1.0",
    no_blur = true,
})

-- Picture-in-Picture (PiP para Firefox, Chrome, etc.)
hl.window_rule({
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)$" },
    opacity = "0.95 0.75",
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

-- Regla opaca para el modo juego (scripts/GameMode.sh la activa/desactiva)
_G.PixiGameModeRule = hl.window_rule({
    name = "gamemode-opaque",
    match = { class = ".*" },
    opacity = "1 override 1 override 1 override",
    enabled = false,
})
