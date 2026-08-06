#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# simple bash script to check if update is available by comparing the
# installed commit (written by copy.sh) against the latest commit on GitHub main

# Local Paths
local_dir="$HOME/.config/hypr"
iDIR="$HOME/.config/swaync/images/"
local_commit=$(cat "$local_dir/.version_commit" 2>/dev/null)
REPO_DIR="$HOME/Pixi-Arch-A"
REPO_URL="https://github.com/0o0-ct/Pixi-Arch-A.git"
branch="main"

# Check for required tools (curl, jq and git)
for tool in curl jq git; do
  if ! command -v "$tool" &> /dev/null; then
    notify-send -i "$iDIR/error.png" "Se necesita $tool:" "$tool no encontrado. Por favor instala $tool."
    exit 1
  fi
done

# Fallback for installs that predate the commit marker: compare version
# files (GitHub vs installed) exactly like the original checker did.
local_version=""
if [ -z "$local_commit" ]; then
  local_version=$(find "$local_dir" -maxdepth 1 -name 'v*' -printf '%f\n' 2>/dev/null | sort -V | tail -n 1 | sed 's/^v//')
fi

github_version=""
if [ -z "$local_commit" ]; then
  github_version=$(curl -fsSL "https://api.github.com/repos/0o0-ct/Pixi-Arch-A/contents/Hyprland-Dots/config/hypr?ref=$branch" | jq -r '.[] | select(.name | startswith("v")) | .name' 2>/dev/null | sort -V | tail -n 1 | sed 's/^v//')
fi

# exit if cannot find local version or commit marker
if [ -z "$local_commit" ] && [ -z "$local_version" ]; then
  notify-send -i "$iDIR/error.png" 'ERROR !?!?!!' "No se pudo encontrar la versión instalada de los dotfiles.\nVuelve a ejecutar copy.sh."
  exit 1
fi

# Cant find GitHub version or commit
if [ -z "$local_commit" ] && [ -z "$github_version" ]; then
  notify-send -i "$iDIR/error.png" 'KooL Hyprland:' "No se pudo determinar la versión de GitHub."
  exit 1
fi

# Comparing local and github versions/commits
update_available=0
if [ -n "$local_commit" ]; then
  github_commit=$(curl -fsSL "https://api.github.com/repos/0o0-ct/Pixi-Arch-A/commits/$branch" | jq -r '.sha' 2>/dev/null)
  if [ -z "$github_commit" ]; then
    notify-send -i "$iDIR/error.png" 'KooL Hyprland:' "No se pudo determinar el commit de GitHub."
    exit 1
  fi
  if [ "$github_commit" != "$local_commit" ]; then
    update_available=1
  fi
else
  if [ "$(echo -e "$github_version\n$local_version" | sort -V | head -n 1)" != "$github_version" ]; then
    update_available=1
  fi
fi

if [ "$update_available" -eq 0 ]; then
   notify-send -i "$iDIR/nota.png" "KooL Hyprland:" "No hay actualización disponible"
  exit 0
else
  # update available
  notify_cmd_base="notify-send -t 10000 -A action1=Update -A action2=NO -h string:x-canonical-private-synchronous:shot-notify"
  notify_cmd_shot="${notify_cmd_base} -i $iDIR/ja.png"

  response=$($notify_cmd_shot "KooL Hyprland:" "Update available! Update now?")

  case "$response" in
    "action1")
      if ! command -v kitty &> /dev/null; then
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Terminal Kitty no encontrada. Por favor instala la terminal Kitty."
        exit 1
      fi
      kitty -e bash -c "
        if [ -d \"$REPO_DIR\" ]; then
          cd \"$REPO_DIR\" &&
          git fetch origin $branch:refs/remotes/origin/$branch &&
          git reset --hard origin/$branch &&
          cd Hyprland-Dots &&
          chmod +x copy.sh &&
          ./copy.sh &&
          notify-send -u critical -i \"$iDIR/ja.png\" 'Actualización Completada:' 'Por favor cierra sesión y vuelve a entrar para aplicar cambios'
        else
          git clone --depth=1 $REPO_URL \"$REPO_DIR\" &&
          cd \"$REPO_DIR/Hyprland-Dots\" &&
          chmod +x copy.sh &&
          ./copy.sh &&
          notify-send -u critical -i \"$iDIR/ja.png\" 'Actualización Completada:' 'Por favor cierra sesión y vuelve a entrar para aplicar cambios'
        fi
      "
      ;;
    "action2")
      exit 0
      ;;
  esac
fi
