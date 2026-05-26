#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Comprobación final de si los paquetes están instalados
# NOTA: Esta comprobación de paquetes es solo de los esenciales

packages=(
  cliphist
  kvantum
  rofi-wayland
  imagemagick
  swaync
  swww
  wallust
  waybar
  wl-clipboard
  wlogout
  kitty
  hypridle
  hyprlock
  hyprland
)

# Local packages that should be in /usr/local/bin/
local_pkgs_installed=(

)

## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
# Determinar el directorio donde se ubica el script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

# Cargar el script de funciones globales
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/00_CHECK-$(date +%d-%H%M%S)_installed.log"

printf "\n%s - Comprobación final para verificar si todos los ${SKY_BLUE}paquetes esenciales${RESET} se instalaron \n" "${NOTE}"
# Inicializar un arreglo vacío para guardar paquetes faltantes
missing=()
local_missing=()

# Función para comprobar si un paquete está instalado usando pacman
is_installed_pacman() {
    pacman -Qi "$1" &>/dev/null
}

# Iterar a través de cada paquete
for pkg in "${packages[@]}"; do
    # Comprobar si los paquetes están instalados
    if ! is_installed_pacman "$pkg"; then
        missing+=("$pkg")
    fi
done

# Comprobar paquetes locales
for pkg1 in "${local_pkgs_installed[@]}"; do
    if ! [ -f "/usr/local/bin/$pkg1" ]; then
        local_missing+=("$pkg1")
    fi
done

# Registrar paquetes faltantes
if [ ${#missing[@]} -eq 0 ] && [ ${#local_missing[@]} -eq 0 ]; then
    echo "${OK} ¡EXCELENTE! Todos los ${YELLOW}paquetes esenciales${RESET} se han instalado correctamente." | tee -a "$LOG"
else
    if [ ${#missing[@]} -ne 0 ]; then
        echo "${WARN} Los siguientes paquetes no están instalados y serán registrados:"
        for pkg in "${missing[@]}"; do
            echo "${WARNING}$pkg${RESET}"
            echo "$pkg" >> "$LOG" 
        done
    fi

    if [ ${#local_missing[@]} -ne 0 ]; then
        echo "${WARN} Faltan los siguientes paquetes locales en /usr/local/bin/ y serán registrados:"
        for pkg1 in "${local_missing[@]}"; do
            echo "${WARNING}$pkg1${REST} no está instalado. No se encuentra en /usr/local/bin/"
            echo "$pkg1" >> "$LOG" 
        done
    fi

    echo "${NOTE} Paquetes faltantes registrados a las $(date)" >> "$LOG"
fi

