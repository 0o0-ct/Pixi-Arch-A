#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Hyprland-Dots to download desde main #


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

# Check if Hyprland-Dots exists
printf "${NOTE} Instalando ${SKY_BLUE}las configuraciones de Pixi-Arch-A${RESET}....\n"

if [ -d Hyprland-Dots ]; then
  cd Hyprland-Dots || exit 1
  chmod +x copy.sh
  ./copy.sh 
else
  # Fallback to cloning desde the new standalone repository Pixi-Arch-A
  if git clone --depth=1 https://github.com/0o0-ct/Pixi-Arch-A.git temp_clone; then
    mv temp_clone/Hyprland-Dots ./Hyprland-Dots
    rm -rf temp_clone
    cd Hyprland-Dots || exit 1
    chmod +x copy.sh
    ./copy.sh
  else
    echo -e "$ERROR No se pudieron descargar las configuraciones de ${YELLOW}Pixi-Arch-A${RESET} . Verifica tu conexión a internet."
  fi
fi

printf "\n%.0s" {1..2}