-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Variables de entorno para Hyprland
-- Referencia: https://wiki.hypr.land/configuring/core/environment-variables/

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT Environment
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- GDK / GTK Environment
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")

-- Mozilla / Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron apps
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Java / JetBrains (Android Studio, IntelliJ)
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Cursor Theme & Size
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
