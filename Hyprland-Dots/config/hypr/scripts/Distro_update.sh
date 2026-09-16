#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Script interactivo de actualización de Sistema y Aplicaciones Arch Linux

iDIR="$HOME/.config/swaync/images"

if ! command -v kitty &> /dev/null; then
  notify-send -i "$iDIR/error.png" "Error:" "Terminal Kitty no encontrada."
  exit 1
fi

if [ -z "$IN_KITTY_DISTRO_UPDATER" ]; then
    export IN_KITTY_DISTRO_UPDATER=1
    exec kitty --title "Arch Linux Package & App Updater" bash -c "$0; echo ''; read -p 'Presiona Enter para cerrar...' key"
    exit 0
fi

echo -e "\e[35m=== 💫 Actualización de Sistema y Aplicaciones Arch Linux 💫 ===\e[0m\n"

if command -v paru &> /dev/null; then
  echo -e "\e[34m[INFO]\e[0m Ejecutando actualización completa con \e[33mparu\e[0m..."
  paru -Syu
elif command -v yay &> /dev/null; then
  echo -e "\e[34m[INFO]\e[0m Ejecutando actualización completa con \e[33myay\e[0m..."
  yay -Syu
else
  echo -e "\e[34m[INFO]\e[0m Ejecutando actualización oficial con \e[33mpacman\e[0m..."
  sudo pacman -Syu
fi

if command -v flatpak &> /dev/null; then
  echo -e "\n\e[34m[INFO]\e[0m Comprobando actualizaciones de aplicaciones \e[33mFlatpak\e[0m..."
  flatpak update -y
fi

# Refresh Waybar update counter immediately
pkill -RTMIN+8 waybar || true

echo -e "\n\e[32m✨ ¡Actualización de Sistema y Aplicaciones completada con éxito!\e[0m"
notify-send -i "$iDIR/ja.png" -u low 'Arch Linux:' 'Sistema y Aplicaciones actualizados.'
