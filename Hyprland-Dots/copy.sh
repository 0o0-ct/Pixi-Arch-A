#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Purpose:
#   Orchestrates copying/upgrading 0o0-ct/Pixi-Arch-A's Hyprland dotfiles into ~/.config.
#   Handles interactive prompts, backups/restores, per-app tweaks, and express mode.
#
# Layout (high-level; future modularization targets):
#   - Constants/colors, helper sourcing (copy_menu.sh, lib_backup.sh, lib_detect.sh, lib_prompts.sh, lib_apps.sh, lib_copy.sh).
#   - New update helper (lib_update.sh) provides menu-driven repo update: verifies Hyprland-Dots root, stashes changes, git pull, logs, summarizes, waits for keypress.
#   - Version helpers and CLI parsing (install/upgrade/express).
#   - Safety checks (non-root), banners/notices.
#   - Environment/distro checks and warnings.
#   - GPU/VM/NixOS detection tweaks (lib_detect.sh).
#   - Input prompts (keyboard, resolution, clock format, animations) (lib_prompts.sh).
#   - Workflow selection effects (express vs standard).
#   - Backup/restore helpers (in scripts/lib_backup.sh).
#   - App enablement/editor selection (lib_apps.sh).
#   - Copy phases (lib_copy.sh):
#       * Part 1: fastfetch/kitty/rofi/swaync (prompted replace).
#       * Waybar special handling (symlinks, configs/styles restore).
#       * Part 2: other configs (btop, cava, hypr, etc.) + ghostty/wezterm installs.
#   - UserConfigs/UserScripts and hypr file restores.
#   - Wallpaper handling (default + optional 1GB pack).
#   - Backup cleanup (auto in express).
#   - Final symlinks (waybar) and wallust init.
#
# Next modular steps:
#   - Restore logic has been moved into lib_copy helpers; review for further
#     consolidation or tests.
#   - Consider modularizing remaining app-specific tweaks/prompts.

clear
wallpaper=$HOME/.config/hypr/wallpaper_effects/.wallpaper_current
waybar_style="$HOME/.config/waybar/style/[Colored] Translucent.css"
waybar_config="$HOME/.config/waybar/configs/[TOP] Default"
waybar_config_laptop="$HOME/.config/waybar/configs/[TOP] Default Laptop"

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
MIN_EXPRESS_VERSION="2.3.18"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_HELPER="$SCRIPT_DIR/scripts/copy_menu.sh"
BACKUP_HELPER="$SCRIPT_DIR/scripts/lib_backup.sh"
DETECT_HELPER="$SCRIPT_DIR/scripts/lib_detect.sh"
PROMPTS_HELPER="$SCRIPT_DIR/scripts/lib_prompts.sh"
APPS_HELPER="$SCRIPT_DIR/scripts/lib_apps.sh"
COPY_HELPER="$SCRIPT_DIR/scripts/lib_copy.sh"
UPDATE_HELPER="$SCRIPT_DIR/scripts/lib_update.sh"
if [ -f "$MENU_HELPER" ]; then
  # shellcheck source=./scripts/copy_menu.sh
  . "$MENU_HELPER"
fi
if [ -f "$BACKUP_HELPER" ]; then
  # shellcheck source=./scripts/lib_backup.sh
  . "$BACKUP_HELPER"
else
  echo "${ERROR} No se encontró el asistente de respaldo en $BACKUP_HELPER. Saliendo."
  exit 1
fi
if [ -f "$DETECT_HELPER" ]; then
  # shellcheck source=./scripts/lib_detect.sh
  . "$DETECT_HELPER"
else
  echo "${ERROR} No se encontró el asistente de detección en $DETECT_HELPER. Saliendo."
  exit 1
fi
if [ -f "$PROMPTS_HELPER" ]; then
  # shellcheck source=./scripts/lib_prompts.sh
  . "$PROMPTS_HELPER"
else
  echo "${ERROR} No se encontró el asistente de avisos en $PROMPTS_HELPER. Saliendo."
  exit 1
fi
if [ -f "$APPS_HELPER" ]; then
  # shellcheck source=./scripts/lib_apps.sh
  . "$APPS_HELPER"
else
  echo "${ERROR} No se encontró el asistente de aplicaciones en $APPS_HELPER. Saliendo."
  exit 1
fi
if [ -f "$COPY_HELPER" ]; then
  # shellcheck source=./scripts/lib_copy.sh
  . "$COPY_HELPER"
else
  echo "${ERROR} No se encontró el asistente de copia en $COPY_HELPER. Saliendo."
  exit 1
fi
if [ -f "$UPDATE_HELPER" ]; then
  # shellcheck source=./scripts/lib_update.sh
  . "$UPDATE_HELPER"
else
  echo "${ERROR} No se encontró el asistente de actualización en $UPDATE_HELPER. Saliendo."
  exit 1
fi

version_gte() {
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | tail -n1)" ]
}

get_installed_dotfiles_version() {
  local hypr_dir="$HOME/.config/hypr"
  if [ -d "$hypr_dir" ]; then
    # Pick the highest semantic version among files named vX.Y.Z
    find "$hypr_dir" -maxdepth 1 -type f -name 'v*.*.*' -printf '%f\n' 2>/dev/null \
      | sed 's/^v//' \
      | sort -V \
      | tail -n1
  fi
}

express_supported() {
  local current_version
  current_version=$(get_installed_dotfiles_version)
  if [ -z "$current_version" ]; then
    return 1
  fi
  version_gte "$current_version" "$MIN_EXPRESS_VERSION"
}
print_usage() {
  cat <<'EOF'
Uso: copy.sh [--upgrade] [--express-upgrade] [--help]

Opciones:
  --upgrade           Ejecuta el script en modo actualización (aún puede sugerir modo exprés).
  --express-upgrade   Actualización exprés (sin preguntas de restauración, recorta respaldos).
  -h, --help          Muestra este mensaje de ayuda y sale.
EOF
}

UPGRADE_MODE=0
EXPRESS_MODE=0
RUN_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --upgrade)
    UPGRADE_MODE=1
    RUN_MODE="upgrade"
    ;;
  --express-upgrade)
    UPGRADE_MODE=1
    EXPRESS_MODE=1
    RUN_MODE="express"
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  *)
    echo "${ERROR} Opción desconocida: $1"
    print_usage
    exit 1
    ;;
  esac
  shift
done
INSTALLED_VERSION=$(get_installed_dotfiles_version)
EXPRESS_SUPPORTED=0
if express_supported; then
  EXPRESS_SUPPORTED=1
fi
if [ "$EXPRESS_MODE" -eq 1 ] && [ "$EXPRESS_SUPPORTED" -eq 0 ]; then
  echo "${WARN} La actualización exprés requiere dotfiles instalados v${MIN_EXPRESS_VERSION} o más recientes. Volviendo a la actualización estándar."
  EXPRESS_MODE=0
  RUN_MODE="upgrade"
fi

if [ -z "$RUN_MODE" ]; then
  if declare -f show_copy_menu >/dev/null 2>&1; then
    while [ -z "$RUN_MODE" ]; do
      show_copy_menu "$EXPRESS_SUPPORTED"
      choice_lower=$(echo "$COPY_MENU_CHOICE" | tr '[:upper:]' '[:lower:]')
      case "$choice_lower" in
      install)
        RUN_MODE="install"
        UPGRADE_MODE=0
        EXPRESS_MODE=0
        ;;
      upgrade)
        RUN_MODE="upgrade"
        UPGRADE_MODE=1
        EXPRESS_MODE=0
        ;;
      express)
        if [ "$EXPRESS_SUPPORTED" -eq 0 ]; then
          echo "${WARN} El modo exprés requiere dotfiles instalados v${MIN_EXPRESS_VERSION} o más recientes. Por favor, elige otra opción."
          continue
        fi
        RUN_MODE="express"
        UPGRADE_MODE=1
        EXPRESS_MODE=1
        ;;
      update)
        run_repo_update "$SCRIPT_DIR"
        # After update, continue showing the menu without exiting
        continue
        ;;
      quit)
        echo "${NOTE} Saliendo según la selección del usuario."
        exit 0
        ;;
      *)
        echo "${WARN} Selección no válida."
        ;;
      esac
    done
  else
    echo "${NOTE} No se encontró el asistente de menú; usando por defecto el flujo de instalación."
    RUN_MODE="install"
  fi
fi

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
  echo "${ERROR} ¡Este script ${WARNING}NO${RESET} debe ser ejecutado como root! Saliendo......."
  printf "\n%.0s" {1..2}
  exit 1
fi

# Function to print colorful text
print_color() {
  # Use %b for the message to interpret backslash escapes like \n, \t, etc.
  printf "%b%b%b\n" "$1" "$2" "$RESET"
}

# Check /etc/os-release for Ubuntu or Debian and warn about Hyprland version requirement
if grep -iqE '^(ID_LIKE|ID)=.*(ubuntu|debian)' /etc/os-release >/dev/null 2>&1; then
  printf "\n%.0s" {1..1}
  print_color $WARNING "\nEstos Dotfiles solo son compatibles con Hyprland v0.50 o superior. No los instales en versiones anteriores de Hyprland.\n"
  while true; do
    echo -n "${CAT} ¿Deseas continuar de todos modos? (s/N): "
    read _continue
    _continue=$(echo "${_continue}" | tr '[:upper:]' '[:lower:]')
    case "${_continue}" in
    s | si | sí | y | yes)
      echo "${NOTE} Procediendo en Ubuntu/Debian por confirmación del usuario."
      break
      ;;
    n | no | "")
      printf "\n%.0s" {1..1}
      echo "${INFO} Cancelando por elección del usuario. No se hicieron cambios."
      printf "\n%.0s" {1..1}
      exit 1
      ;;
    *)
      echo "${WARN} Por favor responde 's' o 'n'."
      ;;
    esac
  done
fi

printf "\n%.0s" {1..1}
echo -e "\e[35m
    ██████╗ ██╗██╗  ██╗██╗      █████╗ ██████╗  ██████╗██╗  ██╗      █████╗ 
    ██╔══██╗██║╚██╗██╔╝██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║     ██╔══██╗
    ██████╔╝██║ ╚███╔╝ ██║     ███████║██████╔╝██║     ███████║     ███████║
    ██╔═══╝ ██║ ██╔██╗ ██║     ██╔══██║██╔══██╗██║     ██╔══██║     ██╔══██║
    ██║     ██║██╔╝ ██╗██║     ██║  ██║██║  ██║╚██████╗██║  ██║     ██║  ██║  2026
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝     ╚═╝  ╚═╝
\e[0m"
printf "\n%.0s" {1..1}

####### Announcement
echo "${WARNING}¡ A T E N C I Ó N !${RESET}"
echo "${MAGENTA}Por favor, visita la Wiki de Pixi-Arch-A para ver los cambios y actualizaciones${RESET}"
printf "\n%.0s" {1..1}

# Create Directory for Copy Logs
if [ ! -d Copy-Logs ]; then
  mkdir Copy-Logs
fi

# Set the name of the log file to include the current date and time
LOG="Copy-Logs/install-$(date +%d-%H%M%S)_dotfiles.log"

# update home directories
xdg-user-dirs-update 2>&1 | tee -a "$LOG" || true
echo "${INFO} Flujo de trabajo seleccionado: ${RUN_MODE}" 2>&1 | tee -a "$LOG"
if [ "$UPGRADE_MODE" -eq 1 ]; then
  echo "${INFO} Modo de actualización activado." 2>&1 | tee -a "$LOG"
fi
if [ "$EXPRESS_MODE" -eq 1 ]; then
  echo "${INFO} Modo exprés activado. Se omitirán las preguntas opcionales de restauración." 2>&1 | tee -a "$LOG"
fi

detect_nvidia_adjust "$LOG"
detect_vm_adjust "$LOG"
detect_nixos_adjust "$LOG"

# activating hyprcursor on env by checking if the directory ~/.icons/Bibata-Modern-Ice/hyprcursors exists
if [ -d "$HOME/.icons/Bibata-Modern-Ice/hyprcursors" ]; then
  HYPRCURSOR_ENV_FILE="config/hypr/configs/ENVariables.conf"
  echo "${INFO} Directorio Bibata-Hyprcursor detectado. Activando Hyprcursor...." 2>&1 | tee -a "$LOG" || true
  sed -i 's/^#env = HYPRCURSOR_THEME,Bibata-Modern-Ice/env = HYPRCURSOR_THEME,Bibata-Modern-Ice/' "$HYPRCURSOR_ENV_FILE"
  sed -i 's/^#env = HYPRCURSOR_SIZE,24/env = HYPRCURSOR_SIZE,24/' "$HYPRCURSOR_ENV_FILE"
fi

printf "\n%.0s" {1..1}

layout=$(prompt_detect_layout)
prompt_keyboard_layout "$layout" "$LOG"

enable_asusctl "$LOG"
enable_blueman "$LOG"
enable_ags "$LOG"
enable_quickshell "$LOG"
ensure_keybinds_init "$LOG"

printf "\n%.0s" {1..1}

choose_default_editor "$LOG"
resolution=""
while true; do
  echo "${INFO} Selecciona la resolución del monitor para el escalado:"
  echo "  1) < 1440p   (DPI bajo; pantallas más pequeñas)"
  echo "  2) ≥ 1440p   (predeterminado; 1440p/2k/4k)"
  echo -n "${CAT} Introduce el número de tu elección (1 o 2): "
  read -r choice
  case "$choice" in
    1) resolution="< 1440p"; break ;;
    2) resolution="≥ 1440p"; break ;;
    *) echo "${ERROR} Elección no válida. Por favor, introduce 1 o 2.";;
  esac
done
echo "${OK} Has elegido la resolución $resolution." 2>&1 | tee -a "$LOG"
if [ "$resolution" == "< 1440p" ]; then
  # kitty font size
  sed -i 's/font_size 16.0/font_size 14.0/' config/kitty/kitty.conf

  # hyprlock matters
  if [ -f config/hypr/hyprlock.conf ]; then
    mv config/hypr/hyprlock.conf config/hypr/hyprlock-2k.conf
  fi
  if [ -f config/hypr/hyprlock-1080p.conf ]; then
    mv config/hypr/hyprlock-1080p.conf config/hypr/hyprlock.conf
  fi

  # rofi fonts reduction
  rofi_config_file="config/rofi/0-shared-fonts.rasi"
  if [ -f "$rofi_config_file" ]; then
    sed -i '/element-text {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 13"/font: "JetBrainsMono Nerd Font SemiBold 11"/' "$rofi_config_file" 2>&1 | tee -a "$LOG"
    sed -i '/configuration {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 15"/font: "JetBrainsMono Nerd Font SemiBold 13"/' "$rofi_config_file" 2>&1 | tee -a "$LOG"
  fi
fi

printf "\n%.0s" {1..1}
prompt_clock_12h "$LOG"
printf "\n%.0s" {1..1}
printf "\n%.0s" {1..1}
prompt_express_upgrade "$EXPRESS_SUPPORTED" "$LOG"

set -e

# Check if the ~/.config/ directory exists
if [ ! -d "$HOME/.config" ]; then
  echo "${ERROR} - El directorio $HOME/.config no existe. Creándolo ahora."
  mkdir -p "$HOME/.config" && echo "Directorio creado con éxito." || echo "No se pudo crear el directorio."
fi

printf "${INFO} - Copiando la ${SKY_BLUE}primera${RESET} parte de los dotfiles\n"
copy_phase1 "$LOG"
printf "\n%.0s" {1..1}
copy_waybar "$LOG"
printf "\n%.0s" {1..1}
printf "${INFO} - Copiando la ${SKY_BLUE}segunda${RESET} parte de los dotfiles\n"
copy_phase2 "$LOG"
printf "\\n%.0s" {1..1}

# ags config
# Check if ags is installed
if command -v ags >/dev/null 2>&1; then
  echo -e "${NOTE} - Se detectó que ${YELLOW}ags${RESET} está instalado"

  DIRPATH_AGS="$HOME/.config/ags"

  if [ ! -d "$DIRPATH_AGS" ]; then
    echo "${INFO} - No se encontró la configuración de ags, copiando nueva configuración."
    if [ -d "config/ags" ]; then
      cp -r "config/ags/" "$DIRPATH_AGS" 2>&1 | tee -a "$LOG"
    fi
  else
    read -p "${CAT} ¿Deseas sobrescribir tu configuración existente de ${YELLOW}ags${RESET}? [s/N] " answer_ags
    case "$answer_ags" in
    [SsYy]*)
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH_AGS" "$DIRPATH_AGS-backup-$BACKUP_DIR" 2>&1 | tee -a "$LOG"
      echo -e "${NOTE} - Se respaldó la configuración de ags en $DIRPATH_AGS-backup-$BACKUP_DIR"

      if cp -r "config/ags/" "$DIRPATH_AGS" 2>&1 | tee -a "$LOG"; then
        echo "${OK} - Configuración de ${YELLOW}ags${RESET} sobrescrita con éxito."
      else
        echo "${ERROR} - Error al copiar la configuración de ${YELLOW}ags${RESET}."
        exit 1
      fi
      ;;
    *)
      echo "${NOTE} - Omitiendo la sobrescritura de la configuración de ags."
      ;;
    esac
  fi
fi

printf "\\n%.0s" {1..1}

# Capture installed dotfiles version at the start of the workflow so we
# can apply cleanup rules based on the pre-upgrade state, even if a newer
# version marker is copied in later.
INSTALLED_VERSION_AT_START="$(get_installed_dotfiles_version || true)"

# quickshell (ags alternative)
# Check if quickshell is installed
if command -v qs >/dev/null 2>&1; then
  echo -e "${NOTE} - Se detectó que ${YELLOW}quickshell${RESET} está instalado"

  DIRPATH_QS="$HOME/.config/quickshell"

  if [ ! -d "$DIRPATH_QS" ]; then
    echo "${INFO} - No se encontró la configuración de quickshell, copiando nueva configuración."
    if [ -d "config/quickshell" ]; then
      cp -r "config/quickshell/" "$DIRPATH_QS" 2>&1 | tee -a "$LOG"
    fi
  else
    # If default shell.qml exists, it blocks named config subdirectory detection
    # Remove it to enable the overview config to be found
    if [ -f "$DIRPATH_QS/shell.qml" ]; then
      echo "${NOTE} - Eliminando el archivo shell.qml predeterminado para permitir la detección de la configuración de vista general de quickshell" 2>&1 | tee -a "$LOG"
      rm "$DIRPATH_QS/shell.qml"
    fi
    
    read -p "${CAT} ¿Deseas sobrescribir tu configuración existente de ${YELLOW}quickshell${RESET}? [s/N] " answer_qs
    case "$answer_qs" in
    [SsYy]*)
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH_QS" "$DIRPATH_QS-backup-$BACKUP_DIR" 2>&1 | tee -a "$LOG"
      echo -e "${NOTE} - Se respaldó quickshell en $DIRPATH_QS-backup-$BACKUP_DIR"

      cp -r "config/quickshell/" "$DIRPATH_QS" 2>&1 | tee -a "$LOG"
      if [ $? -eq 0 ]; then
        echo "${OK} - Configuración de ${YELLOW}quickshell${RESET} sobrescrita con éxito."
        # Remove default shell.qml from new copy to enable overview detection
        rm -f "$DIRPATH_QS/shell.qml" 2>&1 | tee -a "$LOG"
      else
        echo "${ERROR} - Error al copiar la configuración de ${YELLOW}quickshell${RESET}."
        exit 1
      fi
      ;;
    *)
      echo "${NOTE} - Omitiendo la sobrescritura de la configuración de quickshell."
      ;;
    esac
  fi
  
  # Ensure overview subdirectory exists and is up to date
  DIRPATH_OVERVIEW="$DIRPATH_QS/overview"
  if [ ! -d "$DIRPATH_OVERVIEW" ] && [ -d "config/quickshell/overview" ]; then
    echo "${INFO} - Copiando la configuración de vista general de quickshell..." 2>&1 | tee -a "$LOG"
    cp -r "config/quickshell/overview" "$DIRPATH_QS/" 2>&1 | tee -a "$LOG"
    echo "${OK} - Configuración de vista general de quickshell copiada con éxito" 2>&1 | tee -a "$LOG"
  fi
  
  # Check for old quickshell startup commands and update them
  HYPR_STARTUP="$HOME/.config/hypr/configs/Startup_Apps.conf"
  if [ -f "$HYPR_STARTUP" ]; then
    if grep -q '^exec-once = qs\s*$\|^exec-once = qs &' "$HYPR_STARTUP"; then
      echo "${NOTE} - Se encontró un comando de inicio antiguo de Quickshell, actualizando a la nueva configuración de vista general..." 2>&1 | tee -a "$LOG"
      # Replace old 'qs' or 'qs &' with new 'qs -c overview'
      sed -i 's/^\(\s*\)exec-once = qs\s*$/\1exec-once = qs -c overview  # Quickshell Overview/' "$HYPR_STARTUP" 2>&1 | tee -a "$LOG"
      sed -i 's/^\(\s*\)exec-once = qs &$/\1exec-once = qs -c overview  # Quickshell Overview/' "$HYPR_STARTUP" 2>&1 | tee -a "$LOG"
      echo "${OK} - Se actualizó el comando de inicio de Quickshell para usar la configuración de vista general" 2>&1 | tee -a "$LOG"
    fi
  fi
fi
printf "\n%.0s" {1..1}

restore_hypr_assets "$LOG" "$EXPRESS_MODE"
printf "\\n%.0s" {1..1}

restore_user_configs "$LOG" "$EXPRESS_MODE" "$INSTALLED_VERSION_AT_START"
printf "\\n%.0s" {1..1}

restore_user_scripts "$LOG" "$EXPRESS_MODE"
printf "\n%.0s" {1..1}

restore_hypr_files "$LOG" "$EXPRESS_MODE"
printf "\n%.0s" {1..1}
printf "\n%.0s" {1..1}

# Define the target directory for rofi themes
rofi_DIR="$HOME/.local/share/rofi/themes"

if [ ! -d "$rofi_DIR" ]; then
  mkdir -p "$rofi_DIR"
fi
if [ -d "$HOME/.config/rofi/themes" ]; then
  if [ -z "$(ls -A $HOME/.config/rofi/themes)" ]; then
    echo '/* Dummy Rofi theme */' >"$HOME/.config/rofi/themes/dummy.rasi"
  fi
  ln -snf "$HOME/.config/rofi/themes/"* "$HOME/.local/share/rofi/themes/"
  # Delete the dummy file if it was created
  if [ -f "$HOME/.config/rofi/themes/dummy.rasi" ]; then
    rm "$HOME/.config/rofi/themes/dummy.rasi"
  fi
fi

printf "\n%.0s" {1..1}

# wallpaper stuff
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
mkdir -p "$PICTURES_DIR/wallpapers"
if cp -r wallpapers "$PICTURES_DIR/"; then
  echo "${OK} ¡Se copiaron algunos ${MAGENTA}fondos de pantalla${RESET} con éxito!" | tee -a "$LOG"
else
  echo "${ERROR} Error al copiar algunos ${YELLOW}fondos de pantalla${RESET}" | tee -a "$LOG"
fi

# Set some files as executable
chmod +x "$HOME/.config/hypr/scripts/"* 2>&1 | tee -a "$LOG"
chmod +x "$HOME/.config/hypr/UserScripts/"* 2>&1 | tee -a "$LOG"
# Set executable for initial-boot.sh
chmod +x "$HOME/.config/hypr/initial-boot.sh" 2>&1 | tee -a "$LOG"

chassis_type=$(detect_waybar_config)
if [ "$chassis_type" = "desktop" ]; then
  config_file="$waybar_config"
  config_remove=" Laptop"
else
  config_file="$waybar_config_laptop"
  config_remove=""
fi

# Check if ~/.config/waybar/config does not exist or is a symlink
if [ ! -e "$HOME/.config/waybar/config" ] || [ -L "$HOME/.config/waybar/config" ]; then
  ln -sf "$config_file" "$HOME/.config/waybar/config" 2>&1 | tee -a "$LOG"
fi

# Remove inappropriate waybar configs
rm -rf "$HOME/.config/waybar/configs/[TOP] Default$config_remove" \
  "$HOME/.config/waybar/configs/[BOT] Default$config_remove" \
  "$HOME/.config/waybar/configs/[TOP] Default$config_remove (old v1)" \
  "$HOME/.config/waybar/configs/[TOP] Default$config_remove (old v2)" \
  "$HOME/.config/waybar/configs/[TOP] Default$config_remove (old v3)" \
  "$HOME/.config/waybar/configs/[TOP] Default$config_remove (old v4)" 2>&1 | tee -a "$LOG" || true

printf "\n%.0s" {1..1}

# for SDDM (simple_sddm_2)
sddm_simple_sddm_2="/usr/share/sddm/themes/simple_sddm_2"
if [ -d "$sddm_simple_sddm_2" ]; then
  echo "${NOTE} Aplicando automáticamente el fondo de pantalla actual a SDDM..." 2>&1 | tee -a "$LOG"
  if command -v sddm-wallpaper-helper >/dev/null 2>&1; then
    sudo sddm-wallpaper-helper "config/hypr/wallpaper_effects/.wallpaper_current" >/dev/null 2>&1 || true
  else
    sudo cp -f "config/hypr/wallpaper_effects/.wallpaper_current" "$sddm_simple_sddm_2/Backgrounds/default" >/dev/null 2>&1 || true
    sudo sed -i 's|^wallpaper=".*"|wallpaper="Backgrounds/default"|' "$sddm_simple_sddm_2/theme.conf" >/dev/null 2>&1 || true
    sudo sed -i 's|^Background=".*"|Background="Backgrounds/default"|' "$sddm_simple_sddm_2/theme.conf" >/dev/null 2>&1 || true
  fi
fi

# additional wallpapers
printf "\n%.0s" {1..1}
echo "${MAGENTA}Por defecto, solo se copian unos pocos fondos de pantalla${RESET}..."

if [ "$EXPRESS_MODE" -eq 1 ]; then
  echo "${NOTE} Modo exprés: omitiendo la pregunta de descarga de fondos de pantalla adicionales." 2>&1 | tee -a "$LOG"
else
  while true; do
    echo "${NOTE} Descargaremos tus fondos de pantalla personales curados en 4K y HD."
    echo -n "${CAT} ¿Te gustaría descargar tus nuevos fondos de pantalla de alta calidad? (s/n): "
    read WALL

    case $WALL in
    [SsYy])
      echo "${NOTE} Ejecutando el script de descarga de fondos de pantalla personalizados..."
      chmod +x "$SCRIPT_DIR/wallpapers/download_wallpapers.sh" 2>&1 | tee -a "$LOG"
      if "$SCRIPT_DIR/wallpapers/download_wallpapers.sh" 2>&1 | tee -a "$LOG"; then
        echo "${OK} Fondos de pantalla personalizados descargados y sincronizados con éxito." 2>&1 | tee -a "$LOG"
        break
      else
        echo "${ERROR} Error al descargar los fondos de pantalla personalizados." 2>&1 | tee -a "$LOG"
      fi
      ;;
    [Nn]*)
      echo "${NOTE} Elegiste no descargar fondos de pantalla adicionales." 2>&1 | tee -a "$LOG"
      break
      ;;
    *)
      echo "Por favor introduce 's' o 'n' para continuar."
      ;;
    esac
  done
fi

# Execute the cleanup function
if [ "$EXPRESS_MODE" -eq 1 ]; then
  cleanup_backups auto "$LOG"
else
  cleanup_backups prompt "$LOG"
fi

# Check if ~/.config/waybar/style.css does not exist or is a symlink
if [ ! -e "$HOME/.config/waybar/style.css" ] || [ -L "$HOME/.config/waybar/style.css" ]; then
  ln -sf "$waybar_style" "$HOME/.config/waybar/style.css" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..1}

# initialize wallust to avoid config error on hyprland
wallust run -s $wallpaper 2>&1 | tee -a "$LOG"

printf "\n%.0s" {1..2}
printf "${OK} ¡GENIAL! ¡Los Dotfiles de Hyprland de Pixi-Arch-A ya están cargados y listos! "
printf "\n%.0s" {1..1}
printf "${INFO} Sin embargo, se ${MAGENTA}SUGIERE ENFÁTICAMENTE${RESET} cerrar sesión y volver a entrar o, mejor aún, reiniciar para evitar cualquier problema"
printf "\n%.0s" {1..1}
printf "${SKY_BLUE}¡Muchas gracias${RESET} por usar la configuración de Hyprland de ${MAGENTA}Pixi-Arch-A${RESET}... ¡${YELLOW}DISFRÚTALA${RESET}!"
printf "\n%.0s" {1..3}
