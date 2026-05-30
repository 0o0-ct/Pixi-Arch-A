#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# zsh and oh my zsh#

zsh_pkg=(
  lsd
  mercurial
  zsh
  zsh-completions
)

zsh_pkg2=(
  fzf
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_zsh.log"

# Instalando core zsh packages
printf "\n%s - Instalando ${SKY_BLUE}zsh packages${RESET} .... \n" "${NOTE}"
for ZSH in "${zsh_pkg[@]}"; do
  install_package "$ZSH" "$LOG"
done 



# Check if the zsh-completions directory exists
if [ -d "zsh-completions" ]; then
    rm -rf zsh-completions
fi

# Instalar Zsh, plugins y establecer zsh como la shell predeterminada
if command -v zsh >/dev/null; then
  printf "${NOTE} Instalando ${SKY_BLUE}Zsh y plugins de Pixi-Arch-A${RESET} ...\n"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then  
    sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended >> "$LOG" 2>&1
    echo "${OK} ${GREEN}¡Estructura base de Pixi-Arch-A instalada correctamente!${RESET}" 2>&1 | tee -a "$LOG"
  else
    echo "${INFO} El directorio de configuración de Pixi-Arch-A (.oh-my-zsh) ya existe. Omitiendo instalación." 2>&1 | tee -a "$LOG"
  fi
  
  # Comprobar si los directorios existen antes de clonar los repositorios
  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions >> "$LOG" 2>&1
  else
      echo "${INFO} El directorio zsh-autosuggestions ya existe. Omitiendo la descarga." 2>&1 | tee -a "$LOG"
  fi

  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting >> "$LOG" 2>&1
  else
      echo "${INFO} El directorio zsh-syntax-highlighting ya existe. Omitiendo la descarga." 2>&1 | tee -a "$LOG"
  fi
  
  # Comprobar si ~/.zshrc y .zprofile existen, crear copias de seguridad y copiar la nueva configuración
  if [ -f "$HOME/.zshrc" ]; then
      cp -b "$HOME/.zshrc" "$HOME/.zshrc-backup" || true
  fi

  if [ -f "$HOME/.zprofile" ]; then
      cp -b "$HOME/.zprofile" "$HOME/.zprofile-backup" || true
  fi
  
  # Copiar los temas y perfiles preconfigurados de Pixi-Arch-A
  cp -r 'assets/.zshrc' ~/
  cp -r 'assets/.zprofile' ~/

  # Comprobar si la shell actual es zsh
  current_shell=$(basename "$SHELL")
  if [ "$current_shell" != "zsh" ]; then
    printf "${NOTE} Cambiando la shell predeterminada a ${MAGENTA}zsh${RESET}..."
    printf "\n%.0s" {1..2}

    # Bucle para asegurar que el comando chsh tenga éxito
    while ! chsh -s "$(command -v zsh)"; do
      echo "${ERROR} Autenticación fallida. Por favor, introduce la contraseña correcta." 2>&1 | tee -a "$LOG"
      sleep 1
    done

    printf "${INFO} Shell cambiada correctamente a ${MAGENTA}zsh${RESET}\n" 2>&1 | tee -a "$LOG"
  else
    echo "${NOTE} Tu shell ya está configurada como ${MAGENTA}zsh${RESET}."
  fi
  
fi

# Instalando core zsh packages
printf "\n%s - Instalando ${SKY_BLUE}fzf${RESET} .... \n" "${NOTE}"
for ZSH2 in "${zsh_pkg2[@]}"; do
  install_package "$ZSH2" "$LOG"
done

# copiar temas adicionales de Pixi-Arch-A desde assets
if [ -d "$HOME/.oh-my-zsh/themes" ]; then
    cp -r assets/add_zsh_theme/* ~/.oh-my-zsh/themes >> "$LOG" 2>&1
fi

printf "\n%.0s" {1..2}
