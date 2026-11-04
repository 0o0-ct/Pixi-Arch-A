-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Paleta de colores y temas (Hyprland 0.57+)
-- Generado automáticamente por Wallust (matugen)

-- NOTA: Las paletas se generan dinámicamente desde wallpapers
-- usando Wallust + matugen. Ver:
--   Hyprland-Dots/config/ags/matugen/templates/
--   Hyprland-Dots/config/ags/matugen/colors/agc.scss

-- Colores base (ejemplo de estructura)
local colors = {
    -- Primario
    primary = {
        background = "#1E1E2E",
        foreground = "#F5E0DC",
        cursor = "#F5E0DC",
    },

    -- Secundario (accesorio)
    secondary = {
        background = "#3D334A",
        foreground = "#F5E0DC",
        cursor = "#F5E0DC",
    },

    -- Success
    success = {
        background = "#A6E3A1",
        foreground = "#1E1E2E",
    },

    -- Danger
    danger = {
        background = "#F38BA8",
        foreground = "#1E1E2E",
    },

    -- Warning
    warning = {
        background = "#E7C47F",
        foreground = "#1E1E2E",
    },

    -- Info
    info = {
        background = "#74C7EC",
        foreground = "#1E1E2E",
    },
}

-- Exportar colores a variables de entorno para aplicaciones externas
local home = os.getenv("HOME") or ""
os.setenv("PIXI_PRIMARY_BACKGROUND", colors.primary.background)
os.setenv("PIXI_SECONDARY_BACKGROUND", colors.secondary.background)

-- Nota: La paleta real se aplica mediante AGSColors (AGS) y Qtct (Qt)
-- El sistema de paletas se gestiona vía matugen.
