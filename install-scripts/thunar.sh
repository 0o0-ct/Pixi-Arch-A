#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Thunar #

thunar=(
  thunar 
  thunar-volman 
  tumbler
  ffmpegthumbnailer 
  thunar-archive-plugin
  xarchiver
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_thunar.log"

# Thunar
printf "${INFO} Instalando ${SKY_BLUE}Thunar${RESET} Packages...\n"  
  for THUNAR in "${thunar[@]}"; do
    install_package "$THUNAR" "$LOG"
  done

printf "\n%.0s" {1..1}

 # Check for existing configs and copy if does not exist
for DIR1 in gtk-3.0 Thunar xfce4; do
  DIRPATH=~/.config/$DIR1
  if [ -d "$DIRPATH" ]; then
    echo -e "${NOTE} Configuración de ${MAGENTA}$DIR1${RESET} encontrada, no es necesario copiar." 2>&1 | tee -a "$LOG"
  else
    echo -e "${NOTE} Configuración de ${YELLOW}$DIR1${RESET} no encontrada, copiando desde los archivos originales." 2>&1 | tee -a "$LOG"
    cp -r assets/$DIR1 ~/.config/ && echo "${OK} Copia de $DIR1 completada!" || echo "${ERROR} Error al copiar $DIR1 los archivos de configuración." 2>&1 | tee -a "$LOG"
  fi
done

printf "\n%.0s" {1..2}