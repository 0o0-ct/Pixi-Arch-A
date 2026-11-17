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
if git clone --depth=1 https://github.com/JaKooLit/GTK-themes-icons.git ; then
    cd GTK-themes-icons
    chmod +x auto-extract.sh
    ./auto-extract.sh
    cd ..
    if [ -f "Hyprland-Dots/scripts/patch-tray-icons.sh" ]; then
        bash "Hyprland-Dots/scripts/patch-tray-icons.sh" 2>&1 | tee -a "$LOG"
    fi
    echo "$OK Temas GTK e Iconos extraídos en los directorios ~/.icons y ~/.themes" 2>&1 | tee -a "$LOG"
else
    echo "$ERROR Error al descargar los temas GTK e Iconos.." 2>&1 | tee -a "$LOG"
fi

# Installing papirus-folders for dynamic folder colors in file manager
if ! command -v papirus-folders &>/dev/null && [ ! -f "$HOME/.local/bin/papirus-folders" ]; then
    echo "$NOTE Instalando herramienta papirus-folders..." 2>&1 | tee -a "$LOG"
    mkdir -p "$HOME/.local/bin"
    wget -qO "$HOME/.local/bin/papirus-folders" https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders
    chmod +x "$HOME/.local/bin/papirus-folders"
fi

# Installing WhiteSur Icon Theme (Apple iOS / macOS)
if [ ! -d "$HOME/.icons/WhiteSur-dark" ]; then
    echo "$NOTE Instalando colección de iconos Apple WhiteSur (iOS)..." 2>&1 | tee -a "$LOG"
    TEMP_WS=$(mktemp -d)
    if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$TEMP_WS/WhiteSur" 2>&1 | tee -a "$LOG"; then
        "$TEMP_WS/WhiteSur/install.sh" -d "$HOME/.local/share/icons" -a 2>&1 | tee -a "$LOG"
        mkdir -p "$HOME/.icons"
        cp -rn "$HOME/.local/share/icons/WhiteSur"* "$HOME/.icons/" 2>/dev/null || true
    fi
    rm -rf "$TEMP_WS"
fi

# Installing Samsung One UI & Planet Icon Themes
if [ ! -d "$HOME/.icons/OneUI-dark" ]; then
    echo "$NOTE Instalando colección de iconos Samsung One UI..." 2>&1 | tee -a "$LOG"
    TEMP_OUI=$(mktemp -d)
    if git clone --depth=1 https://github.com/mjkim0727/OneUI-Icons.git "$TEMP_OUI/OneUI" 2>&1 | tee -a "$LOG"; then
        mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
        cp -r "$TEMP_OUI/OneUI/OneUI"* "$HOME/.local/share/icons/" 2>/dev/null || true
        cp -r "$TEMP_OUI/OneUI/OneUI"* "$HOME/.icons/" 2>/dev/null || true
    fi
    if git clone --depth=1 https://github.com/mjkim0727/Planet-icons.git "$TEMP_OUI/Planet" 2>&1 | tee -a "$LOG"; then
        cp -r "$TEMP_OUI/Planet/src/Planet"* "$HOME/.local/share/icons/" 2>/dev/null || true
        cp -r "$TEMP_OUI/Planet/src/Planet"* "$HOME/.icons/" 2>/dev/null || true
        gtk-update-icon-cache -f "$HOME/.local/share/icons/Planet"* 2>/dev/null || true
    fi
    rm -rf "$TEMP_OUI"
fi

printf "\n%.0s" {1..2}