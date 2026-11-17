#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# base-devel + archlinux-keyring #

base=( 
  base-devel
  archlinux-keyring
  findutils
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_base.log"

# Instalación de main components with pacman
echo -e "\nInstalando ${SKY_BLUE}base-devel${RESET} and ${SKY_BLUE}archlinux-keyring${RESET}..."

for PKG1 in "${base[@]}"; do
  echo "Instalando $PKG1 con pacman..."
  install_package_pacman "$PKG1" "$LOG"
done

printf "\n%.0s" {1..1}
