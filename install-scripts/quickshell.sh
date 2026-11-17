#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# quickshell - for desktop overview replacing AGS

if [[ $USE_PRESET = [Yy] ]]; then
  source ./preset.sh
fi

quick=(
    qt6-5compat
    quickshell
)

## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || {
  echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"
  exit 1
}

# Cargar el script de funciones globales
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/install-$(date +%d-%H%M%S)_quick.log"

# Instalación de main components
printf "\n%s - Instalando ${SKY_BLUE}Quick Shell ${RESET} for Desktop Overview \n" "${NOTE}"

for PKG1 in "${quick[@]}"; do
  install_package "$PKG1" "$LOG"
done

printf "\n%.0s" {1..1}

