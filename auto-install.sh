#!/bin/bash
# https://github.com/0o0-ct/Pixi-Arch-A

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Variables
Distro="Pixi-Arch-A"
Github_URL="https://github.com/0o0-ct/Pixi-Arch-A.git"
Distro_DIR="$HOME/Pixi-Arch-A"

printf "\n%.0s" {1..1}

if ! command -v git &> /dev/null
then
    echo "${INFO} ¡Git no encontrado! ${SKY_BLUE}Instalando Git...${RESET}"
    if ! sudo pacman -S git --noconfirm; then
        echo "${ERROR} Error al instalar Git. Saliendo."
        exit 1
    fi
fi

printf "\n%.0s" {1..1}

if [ -d "$Distro_DIR" ]; then
    echo "${YELLOW}$Distro_DIR existe. Actualizando el repositorio... ${RESET}"
    cd "$Distro_DIR"
    git stash && git pull
    chmod +x install.sh
    ./install.sh
else
    echo "${MAGENTA}$Distro_DIR no existe. Clonando el repositorio...${RESET}"
    git clone --depth=1 "$Github_URL" "$Distro_DIR"
    cd "$Distro_DIR"
    chmod +x install.sh
    ./install.sh
fi
