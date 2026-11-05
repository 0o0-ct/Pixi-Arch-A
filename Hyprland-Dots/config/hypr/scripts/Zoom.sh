#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Ajusta el zoom del cursor de Hyprland (1.0 - 10.0).
# Uso: Zoom.sh in|out|reset

set -euo pipefail

action="${1:-reset}"
current=$(hyprctl -j getoption cursor:zoom_factor 2>/dev/null | jq -r '.float // 1')

case "$action" in
    in)
        new=$(awk -v c="$current" 'BEGIN { v = c * 2; if (v < 1) v = 1; if (v > 10) v = 10; printf "%.4f", v }')
        ;;
    out)
        new=$(awk -v c="$current" 'BEGIN { v = c / 2; if (v < 1) v = 1; printf "%.4f", v }')
        ;;
    reset)
        new="1.0000"
        ;;
    *)
        echo "Uso: $0 [in|out|reset]" >&2
        exit 2
        ;;
esac

hyprctl eval "hl.config({ cursor = { zoom_factor = $new } })" >/dev/null
