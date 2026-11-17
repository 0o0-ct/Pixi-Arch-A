#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Adding users into input group #

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_input.log"

# Check if the 'input' group exists
if grep -q '^input:' /etc/group; then
    echo "${OK} ${MAGENTA}input${RESET} el grupo existe."
else
    echo "${NOTE} ${MAGENTA}input${RESET} el grupo no existe. Creando ${MAGENTA}input${RESET} group..."
    sudo groupadd input
    echo "${MAGENTA}input${RESET} grupo creado" >> "$LOG"
fi

# Add the user to the 'input' group
sudo usermod -aG input "$(whoami)"
echo "${OK} ${YELLOW}user${RESET} añadido al ${MAGENTA}input${RESET} grupo. Los cambios tendrán efecto después de cerrar e iniciar sesión." >> "$LOG"

printf "\n%.0s" {1..2}
