#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Global Functions for Scripts #

set -e

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

# Create Directorio for Install Logs
if [ ! -d Install-Logs ]; then
    mkdir Install-Logs
fi

# Función para mostrar el progreso
show_progress() {
    local pid=$1
    local package_name=$2
    local spin_chars=("●○○○○○○○○○" "○●○○○○○○○○" "○○●○○○○○○○" "○○○●○○○○○○" "○○○○●○○○○" \
                      "○○○○○●○○○○" "○○○○○○●○○○" "○○○○○○○●○○" "○○○○○○○○●○" "○○○○○○○○○●") 
    local i=0

    tput civis 
    printf "\r${NOTE} Instalando ${YELLOW}%s${RESET} ..." "$package_name"

    while ps -p $pid &> /dev/null; do
        printf "\r${NOTE} Instalando ${YELLOW}%s${RESET} %s" "$package_name" "${spin_chars[i]}"
        i=$(( (i + 1) % 10 ))  
        sleep 0.3  
    done

    printf "\r${NOTE} Instalando ${YELLOW}%s${RESET} ... ¡Hecho!%-20s \n" "$package_name" ""
    tput cnorm  
}



# Función para instalar paquetes con pacman
install_package_pacman() {
  # Comprobar si el paquete ya está instalado
  if pacman -Q "$1" &>/dev/null ; then
    echo -e "${INFO} ${MAGENTA}$1${RESET} ya está instalado. Omitiendo..."
  else
    # Ejecutar pacman y redirigir toda la salida a un archivo de registro
    (
      stdbuf -oL sudo pacman -S --noconfirm "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1" 

    # Doble comprobación de si el paquete está instalado
    if pacman -Q "$1" &>/dev/null ; then
      echo -e "${OK} ¡El paquete ${YELLOW}$1${RESET} se ha instalado correctamente!"
    else
      echo -e "\n${ERROR} Error al instalar ${YELLOW}$1${RESET}. Por favor revisa el archivo de registro $LOG. Es posible que debas instalarlo manualmente."
    fi
  fi
}

ISAUR=$(command -v yay || command -v paru)
# Función para instalar paquetes con yay o paru
install_package() {
  if $ISAUR -Q "$1" &>> /dev/null ; then
    echo -e "${INFO} ${MAGENTA}$1${RESET} ya está instalado. Omitiendo..."
  else
    (
      stdbuf -oL $ISAUR -S --noconfirm "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1"  
    
    # Doble comprobación de si el paquete está instalado
    if $ISAUR -Q "$1" &>> /dev/null ; then
      echo -e "${OK} ¡El paquete ${YELLOW}$1${RESET} se ha instalado correctamente!"
    else
      # Something is missing, exiting to review log
      echo -e "\n${ERROR} Error al instalar ${YELLOW}$1${RESET} :( , por favor revisa el archivo install.log. ¡Es posible que debas instalarlo manualmente! Lo he intentado :("
    fi
  fi
}

# Función para instalar paquetes sin comprobar si están instalados
install_package_f() {
  (
    stdbuf -oL $ISAUR -S --noconfirm "$1" 2>&1
  ) >> "$LOG" 2>&1 &
  PID=$!
  show_progress $PID "$1"  

  # Doble comprobación de si el paquete está instalado
  if $ISAUR -Q "$1" &>> /dev/null ; then
    echo -e "${OK} ¡El paquete ${YELLOW}$1${RESET} se ha instalado correctamente!"
  else
    # Something is missing, exiting to review log
    echo -e "\n${ERROR} Error al instalar ${YELLOW}$1${RESET} :( , por favor revisa el archivo install.log. ¡Es posible que debas instalarlo manualmente! Lo he intentado :("
  fi
}


# Función para eliminar paquetes
uninstall_package() {
  local pkg="$1"

  # Comprobando si el paquete está instalado
  if pacman -Qi "$pkg" &>/dev/null; then
    echo -e "${NOTE} eliminando $pkg ..."
    sudo pacman -R --noconfirm "$pkg" 2>&1 | tee -a "$LOG" | grep -v "error: target not found"
    
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo -e "\e[1A\e[K${OK} $pkg eliminado."
    else
      echo -e "\e[1A\e[K${ERROR} Error al eliminar $pkg. No se requieren acciones."
      return 1
    fi
  else
    echo -e "${INFO} El paquete $pkg no está instalado, omitiendo."
  fi
  return 0
}