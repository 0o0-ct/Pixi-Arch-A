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

# Check for required tools (curl, jq, git)
for tool in curl jq git; do
  if ! command -v "$tool" &> /dev/null; then
    if [ "$IS_STARTUP" -eq 0 ]; then
      notify-send -i "$iDIR/error.png" "Se necesita $tool:" "$tool no encontrado. Por favor instala $tool."
    fi
    exit 1
  fi
done

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

# Get latest commit SHA from GitHub main branch
github_commit=$(curl -fsSL --connect-timeout 8 "https://api.github.com/repos/0o0-ct/Pixi-Arch-A/commits/$branch" | jq -r '.sha' 2>/dev/null | tr -d '[:space:]')

if [ -z "$github_commit" ] || [ "$github_commit" == "null" ]; then
  if [ "$IS_STARTUP" -eq 0 ]; then
    notify-send -i "$iDIR/error.png" 'Pixi-Arch-A Update:' "No se pudo conectar a GitHub para comprobar actualizaciones."
  fi
  exit 1
fi

# Compare SHA hashes (first 7 characters for brevity)
local_short="${local_commit:0:7}"
github_short="${github_commit:0:7}"

if [ -n "$local_commit" ] && [ "$local_commit" == "$github_commit" ]; then
  if [ "$IS_STARTUP" -eq 0 ]; then
    notify-send -i "$iDIR/nota.png" "Pixi-Arch-A:" "Tu sistema está al día con la versión más reciente ($local_short)."
  fi
  exit 0
fi

# An update is AVAILABLE!
notify_title="✨ ¡Actualización de Pixi-Arch-A disponible!"
notify_msg="Hay nuevas mejoras en GitHub (Commit $github_short).\n¿Deseas actualizar tu sistema ahora?"

if [ "$IS_STARTUP" -eq 1 ]; then
    # Background startup notification
    notify-send -u critical -t 15000 -i "$iDIR/ja.png" "$notify_title" "$notify_msg\nHaz clic en la notificación o ejecuta update-dots.sh"
    exit 0
fi

# Interactive update flow
notify_cmd_base="notify-send -t 15000 -A action1=Actualizar -A action2=Luego -h string:x-canonical-private-synchronous:shot-notify"
notify_cmd_shot="${notify_cmd_base} -i $iDIR/ja.png"

response=$($notify_cmd_shot "$notify_title" "$notify_msg")

if [ "$response" == "action1" ] || [ "$IS_STARTUP" -eq 0 ]; then
    if ! command -v kitty &> /dev/null; then
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Terminal Kitty no encontrada."
        exit 1
    fi

    kitty -e bash -c "
        echo -e '\e[35m=== 💫 Actualizando Pixi-Arch-A a la versión ($github_short) 💫 ===\e[0m'
        if [ -d \"$REPO_DIR\" ]; then
            cd \"$REPO_DIR\" &&
            git fetch origin $branch &&
            git reset --hard origin/$branch
        else
            git clone --depth=1 $REPO_URL \"$REPO_DIR\" &&
            cd \"$REPO_DIR\"
        fi

        cd Hyprland-Dots &&
        chmod +x copy.sh &&
        ./copy.sh --express-upgrade &&
        echo \"$github_commit\" > \"$HOME/.config/hypr/.version_commit\" &&
        notify-send -u critical -i \"$iDIR/ja.png\" 'Actualización Completada:' 'Pixi-Arch-A ha sido actualizado al commit $github_short. Reinicia para aplicar todos los cambios.'
    "
fi
