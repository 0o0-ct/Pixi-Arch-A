#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# KooL Arch-Hyprland uninstall script #

clear

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

printf "\n%.0s" {1..2}
echo -e "\e[35m
    ██████╗ ██╗██╗  ██╗██╗      █████╗ ██████╗  ██████╗██╗  ██╗      █████╗ 
    ██╔══██╗██║╚██╗██╔╝██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║     ██╔══██╗
    ██████╔╝██║ ╚███╔╝ ██║     ███████║██████╔╝██║     ███████║     ███████║
    ██╔═══╝ ██║ ██╔██╗ ██║     ██╔══██║██╔══██╗██║     ██╔══██║     ██╔══██║
    ██║     ██║██╔╝ ██╗██║     ██║  ██║██║  ██║╚██████╗██║  ██║     ██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝     ╚═╝  ╚═╝
                         [ U N I N S T A L L ]
\e[0m"
printf "\n%.0s" {1..1}

# Show welcome message using whiptail with Yes/No options
whiptail --title "Script de Desinstalación de Pixi-Arch-A" --yesno \
"¡Hola! Este script desinstalará los paquetes y configuraciones de Pixi-Arch-A.

Podrás elegir los paquetes y directorios que deseas eliminar.
NOTA: Esto eliminará las configuraciones de tu carpeta ~/.config.

ADVERTENCIA: Después de la desinstalación, tu sistema podría quedar inestable.

¿Deseas continuar?" 20 80

if [ $? -eq 1 ]; then
    echo "$INFO Proceso de desinstalación cancelado."
    exit 0
fi

# Function to remove selected packages
remove_packages() {
    local selected_packages_file=$1
    while read -r package; do
        if pacman -Qi "$package" &> /dev/null; then
            echo "Eliminando paquete: $package"
            if ! sudo pacman -Rs --noconfirm "$package"; then
                echo "$ERROR Error al eliminar el paquete: $package"
            else
                echo "$OK Paquete eliminado exitosamente: $package"
            fi
        else
            echo "$INFO Paquete ${YELLOW}$package${RESET} no encontrado. Omitiendo."
        fi
    done < "$selected_packages_file"
}

# Function to remove selected directories
remove_directories() {
    local selected_dirs_file=$1
    while read -r dir; do
        pattern="$HOME/.config/$dir*"        
        # Loop through directories matching the pattern
        for dir_to_remove in $pattern; do
            if [ -d "$dir_to_remove" ]; then
                echo "Eliminando directorio: $dir_to_remove"
                if ! rm -rf "$dir_to_remove"; then
                    echo "$ERROR Error al eliminar el directorio: $dir_to_remove"
                else
                    echo "$OK Directorio eliminado exitosamente: $dir_to_remove"
                fi
            else
                echo "$INFO Directorio ${YELLOW}$dir_to_remove${RESET} no encontrado. Omitiendo."
            fi
        done
    done < "$selected_dirs_file"
}

# Define the list of packages to choose from (with options_command tags)
packages=(
    "btop" "monitor de recursos" "off"
    "brightnessctl" "brightnessctl" "off"
    "cava" "Visualizador de Audio" "off"
    "cliphist" "gestor de portapapeles" "off"
    "fastfetch" "fastfetch" "off"
    "ffmpegthumbnailer" "Generador de miniaturas FFmpeg" "off"
    "grim" "herramienta de capturas de pantalla" "off"
    "imagemagick" "Herramienta de manipulación de imágenes" "off"
    "kitty" "kitty-terminal" "off"
    "kvantum" "Temas para apps QT" "off"
    "mousepad" "editor de texto simple" "off"
    "mpv" "reproductor multimedia" "off"
    "mpv-mpris" "mpv-plugin" "off"
    "network-manager-applet" "network-manager-applet" "off"
    "nvtop" "monitor de recursos gpu" "off"
    "nwg-displays" "app de configuración de monitor" "off"
    "nwg-look" "app de configuración gtk" "off"
    "pamixer" "pamixer" "off"
    "pokemon-colorscripts-git" "scripts de colores de terminal" "off"
    "pavucontrol" "pavucontrol" "off"
    "playerctl" "playerctl" "off"
    "pyprland" "pyprland" "off"
    "qalculate-gtk" "calculadora - QT" "off"
    "qt5ct" "qt5ct" "off"
    "qt6ct" "qt6ct" "off"
    "quickshell" "quickshell" "off"
    "rofi-wayland" "rofi-wayland" "off"
    "slurp" "herramienta de capturas de pantalla" "off"
    "swappy" "herramienta de capturas de pantalla" "off"
    "swaync" "notification agent" "off"
    "swww" "motor de fondos de pantalla" "off"
    "thunar" "Gestor de Archivos" "off"
    "thunar-archive-plugin" "Plugin de Archivos (ZIP/RAR)" "off"
    "thunar-volman" "Gestión de Volúmenes" "off"
    "tumbler" "Servicio de Miniaturas" "off"
    "wallust" "generador de paleta de colores" "off"
    "waybar" "barra de wayland" "off"
    "wl-clipboard" "gestor de portapapeles" "off"
    "wlogout" "menú de cierre de sesión" "off"
    "xdg-desktop-portal-hyprland" "selector de archivos de hyprland" "off"
    "yad" "cajas de diálogo" "off"
    "yt-dlp" "descargador de videos" "off"
    "xarchiver" "Gestor de Archivos comprimidos" "off"
    "hypridle" "agente de inactividad de hyprland" "off"
    "hyprlock" "pantalla de bloqueo" "off"
    "hyprpolkitagent" "agente polkit de hyprland" "off"
    "hyprland" "paquete principal de hyprland" "off"
)

# Define the list of directories to choose from (with options_command tags)
directories=(
    "btop" "configuración de btop" "off"
    "cava" "configuración de cava" "off"
    "fastfetch" "configuración de fastfetch" "off"
    "hypr" "configuración principal de hyprland" "off"
    "kitty" "configuración de la terminal kitty" "off"
    "Kvantum" "configuración de Kvantum-manager" "off"
    "quickshell" "configuración de quickshell desktop overview" "off"
    "qt5ct" "configuración de qt5ct" "off"
    "qt6ct" "configuración de qt6ct" "off"
    "rofi" "configuración de rofi" "off"
    "swappy" "configuración de swappy (capturas)" "off"
    "swaync" "configuración de swaync (notificaciones)" "off"
    "Thunar" "configuración del gestor de archivos Thunar" "off"
    "wallust" "configuración de wallust (paleta de colores)" "off"
    "waybar" "configuración de waybar" "off"
    "wlogout" "configuración de wlogout (menú de salida)" "off"    
)

# Loop for package selection until user selects something or cancels
while true; do
    package_choices=$(whiptail --title "Seleccionar Paquetes a Desinstalar" --checklist \
    "Selecciona los paquetes que quieres eliminar\nNOTA: 'ESPACIO' para seleccionar y 'TAB' para cambiar la selección" 35 90 25 \
    "${packages[@]}" 3>&1 1>&2 2>&3)

    # Check if the user canceled the operation
    if [ $? -eq 1 ]; then
        echo "$INFO proceso de desinstalación cancelado."
        exit 0
    fi

    # If no packages are selected, ask again
    if [[ -z "$package_choices" ]]; then
        echo "$NOTE No se seleccionaron paquetes. Por favor, selecciona al menos un paquete."
    else
        echo "$package_choices" | tr -d '"' | tr ' ' '\n' > /tmp/selected_packages.txt
        echo "Paquetes a eliminar: $package_choices"
        break
    fi
done

# Loop for directory selection until user selects something or cancels
while true; do
    dir_choices=$(whiptail --title "Seleccionar Directorios a Eliminar" --checklist \
    "Selecciona los directorios que deseas eliminar\nNOTA: Esto eliminará configuraciones de ~/.config\n\nNOTA: 'ESPACIO' para seleccionar y 'TAB' para cambiar la selección" 28 90 18 \
    "${directories[@]}" 3>&1 1>&2 2>&3)

    # Check if the user canceled the operation
    if [ $? -eq 1 ]; then
        echo "$INFO proceso de desinstalación cancelado."
        exit 0
    fi

    # If no directories are selected, ask again
    if [[ -z "$dir_choices" ]]; then
        echo "$NOTE No se seleccionaron directorios. Por favor, selecciona al menos un directorio."
    else
        # Save each selected directory to a new line in the temporary file
        echo "$dir_choices" | tr -d '"' | tr ' ' '\n' > /tmp/selected_directories.txt
        echo "Directorios a eliminar: $dir_choices"
        break
    fi
done

# First confirmation - Advertencia about potential instability
if ! whiptail --title "Advertencia" --yesno \
"Advertencia: Removing these packages and directories may cause your system to become unstable and you may not be able to recover it.\n\nAre you sure you want to proceed?" \
10 80; then
    echo "$INFO proceso de desinstalación cancelado."
    exit 0
fi

# Second confirmation - Final confirmation to proceed
if ! whiptail --title "Confirmación Final" --yesno \
"¿Estás absolutamente seguro de que deseas eliminar los paquetes y directorios seleccionados?\n\n¡ADVERTENCIA! Esta acción es irreversible." \
10 80; then
    echo "$INFO proceso de desinstalación cancelado."
    exit 0
fi

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Intentando eliminar los paquetes seleccionados${RESET}\n" "${NOTE}"
MAX_ATTEMPTS=2
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Remove packages
    remove_packages /tmp/selected_packages.txt

    # Check if any packages still need to be removed, retry if needed
    MISSING_PACKAGE_COUNT=0
    while read -r package; do
        if pacman -Qi "$package" &> /dev/null; then
            MISSING_PACKAGE_COUNT=$((MISSING_PACKAGE_COUNT + 1))
        fi
    done < /tmp/selected_packages.txt

    if [ $MISSING_PACKAGE_COUNT -gt 0 ]; then
        ATTEMPT=$((ATTEMPT + 1))
        echo "Intento #$ATTEMPT fallido, reintentando..."
    else
        break
    fi
done

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Intentando eliminar paquetes instalados localmente${RESET}\n" "${NOTE}"
for file in ags pokemon-colorscripts; do
    if [ -f "/usr/local/bin/$file" ]; then
        sudo rm "/usr/local/bin/$file"
        echo "$file eliminado."
    fi
done

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Intentando eliminar directorios seleccionados${RESET}\n" "${NOTE}"
remove_directories /tmp/selected_directories.txt

printf "\n%.0s" {1..1}
echo -e "$MAGENTA Pixi-Arch-A 🇬🇹 y sus componentes relacionados han sido desinstalados.$RESET"
echo -e "$YELLOW Se recomienda reiniciar el sistema ahora.$RESET"
printf "\n%.0s" {1..1}