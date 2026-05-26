#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# GTK Themes & ICONS and  Sourcing desde a different Repo #

engine=(
    unzip
    gtk-engine-murrine
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_themes.log"


# installing engine needed for gtk themes
for PKG1 in "${engine[@]}"; do
    install_package "$PKG1" "$LOG"
done

# Check if the directory exists and delete it if present
if [ -d "GTK-themes-icons" ]; then
    echo "$NOTE El directorio de temas GTK e Iconos existe... eliminando..." 2>&1 | tee -a "$LOG"
    rm -rf "GTK-themes-icons" 2>&1 | tee -a "$LOG"
fi

echo "$NOTE Cloning ${SKY_BLUE}GTK themes and Icons${RESET} repository..." 2>&1 | tee -a "$LOG"
if git clone --depth=1 https://github.com/0o0-ct/Pixi-Arch-A/GTK-themes-icons.git ; then
    cd GTK-themes-icons
    chmod +x auto-extract.sh
    ./auto-extract.sh
    cd ..
    echo "$OK Temas GTK e Iconos extraídos en los directorios ~/.icons y ~/.themes" 2>&1 | tee -a "$LOG"
else
    echo "$ERROR Error al descargar los temas GTK e Iconos.." 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}