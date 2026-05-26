#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Hyprland-Dots to download from main #


## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

# Check if Hyprland-Dots exists
printf "${NOTE} Instalando ${SKY_BLUE}las configuraciones de Pixi-Arch-A${RESET}....\n"

if [ -d Hyprland-Dots ]; then
  cd Hyprland-Dots || exit 1
  chmod +x copy.sh
  ./copy.sh 
else
  # Fallback to cloning from the new standalone repository Pixi-Arch-A
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