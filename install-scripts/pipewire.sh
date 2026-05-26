#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Pipewire and Pipewire Audio Stuff #

pipewire=(
    pipewire
    wireplumber
    pipewire-audio
    pipewire-alsa
    pipewire-pulse
    sof-firmware
)

# added this as some reports script didnt install this.
# basically force reinstall
pipewire_2=(
    pipewire-pulse
)

############## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##############
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

# Cargar el script de funciones globales
source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/install-$(date +%d-%H%M%S)_pipewire.log"

# Disabling pulseaudio to avoid conflicts and logging output
echo -e "${NOTE} Disabling pulseaudio to avoid conflicts..."
systemctl --user disable --now pulseaudio.socket pulseaudio.service >> "$LOG" 2>&1 || true

# Pipewire
echo -e "${NOTE} Instalando ${SKY_BLUE}Pipewire${RESET} Packages..."
for PIPEWIRE in "${pipewire[@]}"; do
    install_package "$PIPEWIRE" "$LOG"
done

for PIPEWIRE2 in "${pipewire_2[@]}"; do
    install_package_pacman "$PIPEWIRE" "$LOG"
done

echo -e "${NOTE} Activating Pipewire Services..."
# Redirect systemctl output to log file
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>&1 | tee -a "$LOG"
systemctl --user enable --now pipewire.service 2>&1 | tee -a "$LOG"

echo -e "\n${OK} Pipewire Installation and services setup complete!" 2>&1 | tee -a "$LOG"

printf "\n%.0s" {1..2}
