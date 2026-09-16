#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Thunar File Manager & Plugins #

thunar_pkg=(
  thunar
  thunar-archive-plugin
  thunar-volman
  thunar-media-tags-plugin
  tumbler
  file-roller
  ffmpegthumbnailer
  poppler-glib
  papirus-icon-theme
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_thunar.log"

# Thunar
printf "${INFO} Instalando ${SKY_BLUE}Thunar File Manager${RESET} & Plugins...\n"  
  for PKG in "${thunar_pkg[@]}"; do
    install_package "$PKG" "$LOG"
  done

printf "\n%.0s" {1..2}
