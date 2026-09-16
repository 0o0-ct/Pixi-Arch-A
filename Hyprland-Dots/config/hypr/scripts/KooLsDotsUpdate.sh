#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Automatic Commit-SHA-based Updater for Pixi-Arch-A

local_dir="$HOME/.config/hypr"
iDIR="$HOME/.config/swaync/images/"
REPO_DIR="$HOME/Pixi-Arch-A"
REPO_URL="https://github.com/0o0-ct/Pixi-Arch-A.git"
branch="main"
IS_STARTUP=0

if [ "$1" == "--startup" ] || [ "$1" == "-s" ]; then
    IS_STARTUP=1
    sleep 15
fi

# If launched interactively from Waybar and not in Kitty terminal, open Kitty terminal window
if [ "$IS_STARTUP" -eq 0 ] && [ -z "$IN_KITTY_UPDATER" ]; then
    export IN_KITTY_UPDATER=1
    exec kitty --title "Pixi-Arch-A Updater" bash -c "$0; echo ''; read -p 'Presiona Enter para salir...' key"
    exit 0
fi

# Determine local commit SHA
local_commit=""
if [ -f "$local_dir/.version_commit" ]; then
    local_commit=$(cat "$local_dir/.version_commit" 2>/dev/null | tr -d '[:space:]')
fi

if [ -z "$local_commit" ] && [ -d "$REPO_DIR/.git" ]; then
    local_commit=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null | tr -d '[:space:]')
    if [ -n "$local_commit" ]; then
        echo "$local_commit" > "$local_dir/.version_commit"
    fi
fi

echo -e "\e[35m=== 💫 Comprobando Actualizaciones de Pixi-Arch-A 💫 ===\e[0m\n"
echo -e "\e[34m[INFO]\e[0m Obteniendo versión más reciente desde GitHub..."

github_commit=$(curl -fsSL --connect-timeout 8 "https://api.github.com/repos/0o0-ct/Pixi-Arch-A/commits/$branch" | jq -r '.sha' 2>/dev/null | tr -d '[:space:]')

if [ -z "$github_commit" ] || [ "$github_commit" == "null" ]; then
    echo -e "\e[31m[ERROR]\e[0m No se pudo conectar a GitHub. Comprueba tu conexión a red."
    if [ "$IS_STARTUP" -eq 0 ]; then
        notify-send -i "$iDIR/error.png" 'Pixi-Arch-A Update:' "No se pudo conectar a GitHub."
    fi
    exit 1
fi

local_short="${local_commit:0:7}"
github_short="${github_commit:0:7}"

echo -e "\e[32m[OK]\e[0m Versión Local:  \e[33m$local_short\e[0m"
echo -e "\e[32m[OK]\e[0m Versión GitHub: \e[33m$github_short\e[0m"

if [ -n "$local_commit" ] && [ "$local_commit" == "$github_commit" ]; then
    echo -e "\n\e[32m✨ ¡Tu personalización Pixi-Arch-A está 100% al día! ($local_short)\e[0m"
    notify-send -i "$iDIR/nota.png" "Pixi-Arch-A:" "Tu sistema está al día ($local_short)."
    exit 0
fi

# Update available
echo -e "\n\e[33m🚀 ¡Nueva actualización disponible en GitHub! (Commit $github_short)\e[0m"
read -p "¿Deseas descargar e instalar la actualización ahora? (s/N): " choice
case "$choice" in
  [sS][sS]*|[sS])
    echo -e "\n\e[35m=== 💫 Instalando Actualizaciones 💫 ===\e[0m"
    rm -rf "$REPO_DIR"
    git clone --depth=1 $REPO_URL "$REPO_DIR"
    if [ -d "$REPO_DIR/Hyprland-Dots" ]; then
        cd "$REPO_DIR/Hyprland-Dots" && chmod +x copy.sh && ./copy.sh --express-upgrade
    fi
    echo "$github_commit" > "$local_dir/.version_commit"
    notify-send -u critical -i "$iDIR/ja.png" 'Actualización Completada:' "Pixi-Arch-A ha sido actualizado a $github_short."
    ;;
  *)
    echo "Operación cancelada."
    ;;
esac
