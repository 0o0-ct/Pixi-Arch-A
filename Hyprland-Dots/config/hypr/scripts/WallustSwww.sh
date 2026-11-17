#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Wallpaper -> colour entrypoint.
#
# This script is intentionally thin: pixi_colors.py is the only writer of the
# generated palette files.  Keep calling this script from wallpaper pickers,
# boot, DarkLight and theme switching so every flow uses the same pipeline.
#
# Usage: WallustSwww.sh [absolute_path_to_wallpaper] [pixi_colors options]
#   WallustSwww.sh --mode light
#   WallustSwww.sh --theme Gruvbox
#   WallustSwww.sh /path/to/image.png --no-reload

export PATH="$HOME/.local/bin:$PATH"

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/pixi_colors.py"

if [[ ! -x "$ENGINE" ]]; then
  echo "pixi_colors.py not found or not executable: $ENGINE" >&2
  exit 1
fi

exec python3 "$ENGINE" "$@"
