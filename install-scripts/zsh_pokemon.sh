#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# pokemon-color-scripts#

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_zsh_pokemon.log"

printf "${NOTE} Removing any traces of ${SKY_BLUE}Pokemon Color Scripts${RESET}\n"

# Install Pokemon Color Scripts
printf "${NOTE} Instalando ${SKY_BLUE}Pokemon Color Scripts${RESET}\n"
for pok in "pokemon-colorscripts-git"; do
  install_package_f "$pok" "$LOG"
done

printf "\n%.0s" {1..1}
# Check if ~/.zshrc exists
if [ -f "$HOME/.zshrc" ]; then
	sed -i 's|^#pokemon-colorscripts --no-title -s -r \| fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|pokemon-colorscripts --no-title -s -r \| fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|' "$HOME/.zshrc" >> "$LOG" 2>&1
	sed -i "s|^fastfetch -c \$HOME/.config/fastfetch/config-compact.jsonc|#fastfetch -c \$HOME/.config/fastfetch/config-compact.jsonc|" "$HOME/.zshrc" >> "$LOG" 2>&1
else
    echo "$HOME/.zshrc not found. Cant enable ${YELLOW}Pokemon color scripts${RESET}" >> "$LOG" 2>&1
fi
  
printf "\n%.0s" {1..2}
