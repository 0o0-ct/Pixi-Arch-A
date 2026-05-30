#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# SDDM themes #

source_theme="https://github.com/JaKooLit/simple-sddm-2.git"
theme_name="simple_sddm_2"

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_sddm_theme.log"
    
# SDDM-themes
printf "${INFO} Instalando el ${SKY_BLUE}Tema Adicional de SDDM${RESET}\n"

# Comprobar si /usr/share/sddm/themes/$theme_name existe y eliminarlo si es así
if [ -d "/usr/share/sddm/themes/$theme_name" ]; then
  sudo rm -rf "/usr/share/sddm/themes/$theme_name"
  echo -e "\e[1A\e[K${OK} - Se eliminó el directorio existente de $theme_name." 2>&1 | tee -a "$LOG"
fi

# Comprobar si el directorio $theme_name existe en el directorio actual y eliminarlo si es así
if [ -d "$theme_name" ]; then
  rm -rf "$theme_name"
  echo -e "\e[1A\e[K${OK} - Se eliminó el directorio existente de $theme_name de la ubicación actual." 2>&1 | tee -a "$LOG"
fi

# Clonar el repositorio
if git clone --depth=1 "$source_theme" "$theme_name"; then
  if [ ! -d "$theme_name" ]; then
    echo "${ERROR} Error al clonar el repositorio." | tee -a "$LOG"
  fi

  # Crear el directorio de temas si no existe
  if [ ! -d "/usr/share/sddm/themes" ]; then
    sudo mkdir -p /usr/share/sddm/themes
    echo "${OK} - Directorio '/usr/share/sddm/themes' creado." | tee -a "$LOG"
  fi

  # Mover el tema clonado al directorio de temas
  sudo mv "$theme_name" "/usr/share/sddm/themes/$theme_name" 2>&1 | tee -a "$LOG"

  # Configurar el tema en SDDM
  sddm_conf="/etc/sddm.conf"
  BACKUP_SUFFIX=".bak"

  echo -e "${NOTE} Configurando la pantalla de inicio de sesión." | tee -a "$LOG"

  # Crear una copia de seguridad del archivo sddm.conf si existe
  if [ -f "$sddm_conf" ]; then
    echo "Creando copia de seguridad de $sddm_conf" | tee -a "$LOG"
    sudo cp "$sddm_conf" "$sddm_conf$BACKUP_SUFFIX" 2>&1 | tee -a "$LOG"
  else
    echo "$sddm_conf no existe, creando uno nuevo." | tee -a "$LOG"
    sudo touch "$sddm_conf" 2>&1 | tee -a "$LOG"
  fi

  # Comprobar si la sección [Theme] existe
  if grep -q '^\[Theme\]' "$sddm_conf"; then
    # Actualizar la línea Current= bajo la sección [Theme]
    sudo sed -i "/^\[Theme\]/,/^\[/{s/^\s*Current=.*/Current=$theme_name/}" "$sddm_conf" 2>&1 | tee -a "$LOG"
    
    # Si no se encontró ni reemplazó la línea Current=, añadirla después de la sección [Theme]
    if ! grep -q '^\s*Current=' "$sddm_conf"; then
      sudo sed -i "/^\[Theme\]/a Current=$theme_name" "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Se añadió Current=$theme_name bajo [Theme] en $sddm_conf" | tee -a "$LOG"
    else
      echo "Se actualizó Current=$theme_name en $sddm_conf" | tee -a "$LOG"
    fi
  else
    # Añadir la sección [Theme] al final si no existe
    echo -e "\n[Theme]\nCurrent=$theme_name" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Se añadió la sección [Theme] con Current=$theme_name en $sddm_conf" | tee -a "$LOG"
  fi

  # Añadir la sección [General] con InputMethod=qtvirtualkeyboard si no existe
  if ! grep -q '^\[General\]' "$sddm_conf"; then
    echo -e "\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Se añadió la sección [General] con InputMethod=qtvirtualkeyboard en $sddm_conf" | tee -a "$LOG"
  else
    # Actualizar la línea InputMethod si la sección existe
    if grep -q '^\s*InputMethod=' "$sddm_conf"; then
      sudo sed -i '/^\[General\]/,/^\[/{s/^\s*InputMethod=.*/InputMethod=qtvirtualkeyboard/}' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Se actualizó InputMethod a qtvirtualkeyboard en $sddm_conf" | tee -a "$LOG"
    else
      sudo sed -i '/^\[General\]/a InputMethod=qtvirtualkeyboard' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Se añadió InputMethod=qtvirtualkeyboard bajo [General] en $sddm_conf" | tee -a "$LOG"
    fi
  fi

  # Reemplazar el fondo actual desde la carpeta assets
  sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
  sudo sed -i 's|^wallpaper=".*"|wallpaper="Backgrounds/default"|' "/usr/share/sddm/themes/$theme_name/theme.conf" 2>&1 | tee -a "$LOG"

  echo "${OK} - Tema adicional de SDDM ${YELLOW}$theme_name${RESET} instalado con éxito." | tee -a "$LOG"

else

  echo "${ERROR} - No se pudo clonar el repositorio del tema SDDM. Por favor, comprueba tu conexión a Internet." | tee -a "$LOG" >&2
fi

printf "\n%.0s" {1..2}