#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Main Hyprland Package #

hypr_eco=(
  hypridle
  hyprlock
)

hypr=(
  hyprland
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_hyprland.log"

# Check if Hyprland is installed
if command -v Hyprland >/dev/null 2>&1; then
  printf "$NOTE - ${YELLOW} Hyprland is ya instalado.${RESET} No action required.\n"
else
  printf "$INFO - Hyprland not found. ${SKY_BLUE} Instalando Hyprland...${RESET}\n"
  for HYPRLAND in "${hypr[@]}"; do
    install_package "$HYPRLAND" "$LOG"
  done
fi

# Hyprland -eco packages
printf "${NOTE} - Instalando ${SKY_BLUE}other Hyprland-eco packages${RESET} .......\n"
for HYPR in "${hypr_eco[@]}"; do
  if ! command -v "$HYPR" >/dev/null 2>&1; then
    printf "$INFO - ${YELLOW}$HYPR${RESET} not found. Instalando ${YELLOW}$HYPR...${RESET}\n"
    install_package "$HYPR" "$LOG"
  else
    printf "$NOTE - ${YELLOW} $HYPR is ya instalado.${RESET} No action required.\n"
  fi
done

printf "\n%.0s" {1..2}