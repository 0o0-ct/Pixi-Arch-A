#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Main Hyprland Package #

hypr_eco=(
  hypridle
  hyprlock
  hyprsunset
  hyprpolkitagent
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
  current_ver=$(Hyprland --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
  printf "$NOTE - ${YELLOW}Hyprland ya está instalado (versión detectada: ${current_ver:-desconocida}).${RESET}\n"
  printf "$INFO - ${SKY_BLUE}Asegurando que Hyprland esté actualizado a la última versión disponible (0.57+ Lua)...${RESET}\n"
  install_package_f "hyprland"
else
  printf "$INFO - Hyprland not found. ${SKY_BLUE} Instalando Hyprland...${RESET}\n"
  for HYPRLAND in "${hypr[@]}"; do
    install_package "$HYPRLAND" "$LOG"
  done
fi

# Hyprland -eco packages
printf "${NOTE} - Instalando / actualizando ${SKY_BLUE}paquetes del ecosistema Hyprland${RESET} .......\n"
for HYPR in "${hypr_eco[@]}"; do
  if ! command -v "$HYPR" >/dev/null 2>&1 && ! pacman -Qi "$HYPR" >/dev/null 2>&1; then
    printf "$INFO - ${YELLOW}$HYPR${RESET} no encontrado. Instalando ${YELLOW}$HYPR...${RESET}\n"
    install_package "$HYPR" "$LOG"
  else
    printf "$NOTE - ${YELLOW}$HYPR${RESET} ya instalado. Asegurando última versión...\n"
    install_package_f "$HYPR"
  fi
done

printf "\n%.0s" {1..2}
