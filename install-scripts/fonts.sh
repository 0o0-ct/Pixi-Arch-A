#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Fonts #

# These fonts are minimun required for pre-configured dots to work. You can add here as required
# WARNING! If you remove packages here, dotfiles may not work properly.
# and also, ensure that packages are present in AUR and official Arch Repo

fonts=(
  adobe-source-code-pro-fonts 
  noto-fonts-emoji
  otf-font-awesome 
  ttf-droid 
  ttf-fira-code
  ttf-fantasque-nerd
  ttf-jetbrains-mono 
  ttf-jetbrains-mono-nerd
  ttf-victor-mono
  noto-fonts
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_fonts.log"


# Instalación de main components
printf "\n%s - Instalando necessary ${SKY_BLUE}fonts${RESET}.... \n" "${NOTE}"

for PKG1 in "${fonts[@]}"; do
  install_package "$PKG1" "$LOG"
done

printf "\n%.0s" {1..2}