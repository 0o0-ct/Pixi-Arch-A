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

# Copiar el tema personalizado desde el repositorio de dotfiles
local_theme_path="Hyprland-Dots/assets/sddm_theme/$theme_name"

if [ -d "$local_theme_path" ]; then
  # Crear el directorio de temas si no existe
  if [ ! -d "/usr/share/sddm/themes" ]; then
    sudo mkdir -p /usr/share/sddm/themes
    echo "${OK} - Directorio '/usr/share/sddm/themes' creado." | tee -a "$LOG"
  fi

  # Copiar el tema al directorio de temas
  sudo cp -r "$local_theme_path" "/usr/share/sddm/themes/" 2>&1 | tee -a "$LOG"

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

  # Reemplazar el fondo actual por uno de la colección de wallpapers para evitar el fondo aburrido por defecto
  sddm_bg=""
  if [ -d "Hyprland-Dots/wallpapers" ]; then
    sddm_bg=$(find "Hyprland-Dots/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
  fi
  if [ -z "$sddm_bg" ] && [ -d "wallpapers" ]; then
    sddm_bg=$(find "wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
  fi

  if [ -n "$sddm_bg" ] && [ -f "$sddm_bg" ]; then
    echo "Aplicando wallpaper inicial para SDDM: $sddm_bg" | tee -a "$LOG"
    sudo cp -f "$sddm_bg" "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
  else
    sudo cp -f assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
  fi
  sudo sed -i 's|^wallpaper=".*"|wallpaper="Backgrounds/default"|' "/usr/share/sddm/themes/$theme_name/theme.conf" 2>&1 | tee -a "$LOG"
  sudo sed -i 's|^Background=".*"|Background="Backgrounds/default"|' "/usr/share/sddm/themes/$theme_name/theme.conf" 2>&1 | tee -a "$LOG"

  # --- Instalar el ayudante seguro de fondos de pantalla de SDDM para evitar peticiones de contraseña ---
  HELPER_PATH="/usr/local/bin/sddm-wallpaper-helper"
  SUDOERS_PATH="/etc/sudoers.d/sddm-wallpaper-helper"

  echo "Instalando sddm-wallpaper-helper en $HELPER_PATH..." | tee -a "$LOG"
  sudo tee "$HELPER_PATH" > /dev/null << 'EOF'
#!/usr/bin/env bash
# Secures and automates SDDM wallpaper and color updates without prompts.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <wallpaper_path> [theme_name]" >&2
    exit 1
fi

WALLPAPER_PATH="$1"
THEME_NAME="${2:-simple_sddm_2}"

if [[ ! -f "$WALLPAPER_PATH" ]]; then
    echo "Error: Wallpaper file $WALLPAPER_PATH does not exist." >&2
    exit 1
fi

# Ensure target theme exists
SDDM_THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
if [[ ! -d "$SDDM_THEME_DIR" ]]; then
    echo "Error: SDDM theme directory $SDDM_THEME_DIR does not exist." >&2
    exit 1
fi

# Copy wallpaper retaining the extension so QML loader does not fail
MIME=$(file --mime-type -b "$WALLPAPER_PATH" 2>/dev/null || echo "")
case "$MIME" in
    image/jpeg) EXT="jpg" ;;
    image/png) EXT="png" ;;
    image/webp) EXT="webp" ;;
    *)
        EXT="${WALLPAPER_PATH##*.}"
        if [[ "$EXT" == "$WALLPAPER_PATH" || "${#EXT}" -gt 5 ]]; then
            EXT="png"
        fi
        ;;
esac

TARGET_BG_DIR="$SDDM_THEME_DIR/Backgrounds"
mkdir -p "$TARGET_BG_DIR"
rm -f "$TARGET_BG_DIR"/default*

cp -f "$WALLPAPER_PATH" "$TARGET_BG_DIR/default.$EXT"
chmod 644 "$TARGET_BG_DIR/default.$EXT"

# Set wallpaper parameter in theme.conf
THEME_CONF="$SDDM_THEME_DIR/theme.conf"
if [[ -f "$THEME_CONF" ]]; then
    sed -i "s|^wallpaper=\".*\"|wallpaper=\"Backgrounds/default.$EXT\"|" "$THEME_CONF"
    sed -i "s|^Background=\".*\"|Background=\"Backgrounds/default.$EXT\"|" "$THEME_CONF"
fi

# If colors-rofi.rasi exists, extract and apply colors
if [[ "$WALLPAPER_PATH" =~ ^/home/([^/]+)/ ]]; then
    USER_HOME="/home/${BASH_REMATCH[1]}"
else
    USER_HOME="${HOME:-/home/${SUDO_USER:-$(whoami)}}"
fi
ROFI_WALLUST="$USER_HOME/.config/rofi/wallust/colors-rofi.rasi"

if [[ -f "$ROFI_WALLUST" && -f "$THEME_CONF" ]]; then
    extract_color() {
        local key="$1"
        grep -oP "$key:\s*\K#[A-Fa-f0-9]+" "$ROFI_WALLUST" | head -n1 || echo ""
    }

    color0=$(extract_color "color1")
    color1=$(extract_color "color0")
    color7=$(extract_color "color14")
    color10=$(extract_color "color10")
    color12=$(extract_color "color12")
    color13=$(extract_color "color13")

    if [[ -n "$color13" ]]; then
        sed -i "s/HeaderTextColor=\"#.*\"/HeaderTextColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/DateTextColor=\"#.*\"/DateTextColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/TimeTextColor=\"#.*\"/TimeTextColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/DropdownSelectedBackgroundColor=\"#.*\"/DropdownSelectedBackgroundColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/SystemButtonsIconsColor=\"#.*\"/SystemButtonsIconsColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/SessionButtonTextColor=\"#.*\"/SessionButtonTextColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/VirtualTecladoButtonTextColor=\"#.*\"/VirtualTecladoButtonTextColor=\"$color13\"/" "$THEME_CONF"
        sed -i "s/VirtualKeyboardButtonTextColor=\"#.*\"/VirtualKeyboardButtonTextColor=\"$color13\"/" "$THEME_CONF"
    fi

    if [[ -n "$color12" ]]; then
        sed -i "s/HighlightBackgroundColor=\"#.*\"/HighlightBackgroundColor=\"$color12\"/" "$THEME_CONF"
        sed -i "s/LoginFieldTextColor=\"#.*\"/LoginFieldTextColor=\"$color12\"/" "$THEME_CONF"
        sed -i "s/PasswordFieldTextColor=\"#.*\"/PasswordFieldTextColor=\"$color12\"/" "$THEME_CONF"
    fi

    if [[ -n "$color1" ]]; then
        sed -i "s/DropdownBackgroundColor=\"#.*\"/DropdownBackgroundColor=\"$color1\"/" "$THEME_CONF"
    fi

    if [[ -n "$color10" ]]; then
        sed -i "s/HighlightTextColor=\"#.*\"/HighlightTextColor=\"$color10\"/" "$THEME_CONF"
    fi

    if [[ -n "$color7" ]]; then
        sed -i "s/PlaceholderTextColor=\"#.*\"/PlaceholderTextColor=\"$color7\"/" "$THEME_CONF"
        sed -i "s/UserIconColor=\"#.*\"/UserIconColor=\"$color7\"/" "$THEME_CONF"
        sed -i "s/PasswordIconColor=\"#.*\"/PasswordIconColor=\"$color7\"/" "$THEME_CONF"
    fi
fi

echo "SDDM colors and wallpaper updated successfully."
EOF
  sudo chmod 755 "$HELPER_PATH"

  echo "Configurando regla sudoers sin contraseña para el ayudante..." | tee -a "$LOG"
  echo "ALL ALL=(ALL) NOPASSWD: $HELPER_PATH" | sudo tee "$SUDOERS_PATH" > /dev/null
  sudo chmod 440 "$SUDOERS_PATH"

  echo "${OK} - Tema adicional de SDDM ${YELLOW}$theme_name${RESET} instalado con éxito con ayudante seguro." | tee -a "$LOG"

else

  echo "${ERROR} - No se encontró el tema local en $local_theme_path." | tee -a "$LOG" >&2
fi

printf "\n%.0s" {1..2}