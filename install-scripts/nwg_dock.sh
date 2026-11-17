#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# nwg-dock-hyprland (Floating macOS-style Dock) #
# https://github.com/nwg-piotr/nwg-dock-hyprland

nwg_dock_pkg=(
  nwg-dock-hyprland
)

## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

# Cargar el script de funciones globales
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/install-$(date +%d-%H%M-%S)_nwg_dock.log"

CONFIG_DIR="$HOME/.config/nwg-dock-hyprland"

# nwg-dock-hyprland
printf "${INFO} Instalando ${SKY_BLUE}nwg-dock-hyprland (Floating macOS Dock)${RESET}...\n"
  for PKG in "${nwg_dock_pkg[@]}"; do
    install_package "$PKG" "$LOG"
  done

# --- Copiar la configuración del dock ------------------------------------
# Hyprland-Dots/config es el origen; $HOME/.config es el caso de quien ya
# tiene todo copiado a mano (instaladores antiguos).
HYPRLAND_DOTS_CONFIG=""
for candidate in \
    "$PARENT_DIR/Hyprland-Dots/config" \
    "$HOME/.config"; do
    if [[ -d "$candidate/nwg-dock-hyprland" ]]; then
        HYPRLAND_DOTS_CONFIG="$candidate"
        break
    fi
done

if [[ -n "$HYPRLAND_DOTS_CONFIG" ]]; then
    mkdir -p "$CONFIG_DIR"
    if [[ -f "$HYPRLAND_DOTS_CONFIG/nwg-dock-hyprland/style.css" ]]; then
        # style.css se sobrescribe a proposito: el fondo de la capa depende de
        # el (window transparente) y de la regla del tema GTK3. Con el CSS
        # antiguo el dock vuelve a pintar la capa base oscura.
        cp -f "$HYPRLAND_DOTS_CONFIG/nwg-dock-hyprland/style.css" "$CONFIG_DIR/style.css"
        printf "${OK} style.css copiado a ${CONFIG_DIR}/\n"
    fi
    if [[ -f "$HYPRLAND_DOTS_CONFIG/nwg-dock-hyprland/pinned" ]]; then
        # pinned es del usuario: nunca se sobrescribe.
        cp -n "$HYPRLAND_DOTS_CONFIG/nwg-dock-hyprland/pinned" "$CONFIG_DIR/pinned"
        printf "${OK} pinned copiado a ${CONFIG_DIR}/\n"
    fi
else
    printf "${WARN} No se encontró config/nwg-dock-hyprland/ en Hyprland-Dots.\n"
fi

# --- Colores iniciales del dock ------------------------------------------
# El fondo cristal de ventanas vive en el tema GTK3 (prioridad SETTINGS) y lo
# aplica pixi_colors.py; sin esto el dock conserva la capa base oscura.
if [[ -x "$HOME/.config/hypr/scripts/pixi_colors.py" ]]; then
    printf "${INFO} Generando colores iniciales del dock...\n"
    python3 "$HOME/.config/hypr/scripts/pixi_colors.py" 2>&1 | tee -a "$LOG" || true
fi

printf "\n%.0s" {1..2}
printf "${OK} nwg-dock-hyprland configurado correctamente.\n"
printf "${CAT} El dock se inicia automáticamente con Hyprland.\n"
printf "${CAT} Toggle con: ${SKY_BLUE}SUPER + CTRL + D${RESET}\n"
printf "${CAT} Config en: ${SKY_BLUE}${CONFIG_DIR}/style.css${RESET}\n"
printf "\n%.0s" {1..2}
