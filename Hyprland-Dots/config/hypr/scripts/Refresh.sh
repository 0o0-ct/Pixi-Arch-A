#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Refresh the shell chrome after a layout/style change.
#
# Colour regeneration is owned by pixi_colors.py and WallustSwww.sh.  This
# script deliberately does not run Wallust, does not kill rofi/AGS/QuickShell,
# and does not restart SwayNC: restarting them would drop unrelated panels and
# notifications for a Waybar stylesheet change.  Only Waybar is restarted,
# because Waybar 0.15 does not reliably re-read a changed @import graph, and
# SwayNC receives a config/CSS reload so its monitor-aware layout follows.

set -uo pipefail

UserScripts="${HOME}/.config/hypr/UserScripts"
SwayNCConfig="${HOME}/.config/swaync/config.json"
SwayNCLayout="${HOME}/.config/swaync/layout.css"

file_exists() {
  [ -e "$1" ]
}

# ---------------------------------------------------------------------------
# SwayNC layout follows the active Waybar config (top/bottom/left/right).
# ---------------------------------------------------------------------------
positionX="right"
positionY="top"
width=450
height=720

if [ -L "${HOME}/.config/waybar/config" ]; then
  layout_name=$(basename "$(readlink -f "${HOME}/.config/waybar/config")")

  case "$layout_name" in
    *"[TOP & BOT]"*) positionX="right"; positionY="bottom" ;;
    *"[BOT & Left]"*|*"[BOT & LEFT]"*) positionX="left"; positionY="bottom" ;;
    *"[BOT & Right]"*|*"[BOT & RIGHT]"*) positionX="right"; positionY="bottom" ;;
    *"[TOP & Left]"*|*"[TOP & LEFT]"*) positionX="left"; positionY="top" ;;
    *"[TOP & Right]"*|*"[TOP & RIGHT]"*) positionX="right"; positionY="top" ;;
    *"[LEFT]"*) positionX="left"; positionY="bottom" ;;
    *"[RIGHT]"*) positionX="right"; positionY="bottom" ;;
    *"[BOT]"*) positionX="right"; positionY="bottom" ;;
    *"[TOP]"*) positionX="right"; positionY="top" ;;
  esac

  if [ "$positionX" = "left" ]; then
    width=720
    height=450
  elif [ "$positionX" = "right" ] && [[ "$layout_name" == *"[RIGHT]"* ]]; then
    width=720
    height=450
  fi
fi

if [ -f "$SwayNCConfig" ] && command -v jq >/dev/null 2>&1; then
  tmp="${SwayNCConfig}.pixi.$$"
  if jq --arg px "$positionX" --arg py "$positionY" \
        --argjson w "$width" --argjson h "$height" \
        '.positionX = $px | .positionY = $py
         | ."control-center-width" = $w
         | ."control-center-height" = $h' \
        "$SwayNCConfig" > "$tmp"; then
    mv "$tmp" "$SwayNCConfig"
  else
    rm -f "$tmp"
  fi
fi

# SwayNC's two-column layout is CSS rather than a widget property.
if [ "$width" -eq 720 ]; then
  cat > "${SwayNCLayout}.tmp.$$" <<'EOF'
/* Horizontal Layout - Two Columns */
.control-center, .control-center > box {
    display: flex;
    flex-direction: column;
    flex-wrap: wrap;
    height: 410px;
}
.widget-dnd, .widget-buttons-grid, .widget-mpris, .widget-volume, .widget-backlight, .widget-title, .control-center-list {
    width: 330px;
    min-width: 330px;
    max-width: 330px;
}
EOF
else
  cat > "${SwayNCLayout}.tmp.$$" <<'EOF'
/* Vertical Layout - Single Column */
.control-center, .control-center > box {
    display: flex;
    flex-direction: column;
    flex-wrap: nowrap;
    height: auto;
}
.widget-dnd, .widget-buttons-grid, .widget-mpris, .widget-volume, .widget-backlight, .widget-title, .control-center-list {
    width: auto;
    min-width: 0;
    max-width: none;
}
EOF
fi
mv "${SwayNCLayout}.tmp.$$" "$SwayNCLayout"

# Reload SwayNC in place.  -R re-reads config.json, -rs re-reads style.css.
if pgrep -x swaync >/dev/null 2>&1 && command -v swaync-client >/dev/null 2>&1; then
  swaync-client -R -rs >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Waybar: restart only this process.  A style/layout switch cannot be applied
# by a CSS reload on 0.15, and a full desktop restart would be far too broad.
# ---------------------------------------------------------------------------
if pgrep -x waybar >/dev/null 2>&1; then
  pkill -x waybar >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    pgrep -x waybar >/dev/null 2>&1 || break
    sleep 0.1
  done
  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -9 -x waybar >/dev/null 2>&1 || true
    sleep 0.1
  fi
fi

if command -v waybar >/dev/null 2>&1; then
  nohup waybar >/dev/null 2>&1 &
  disown || true
fi

# Rainbow borders are a separate decoration; keep the existing opt-in.
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  "${UserScripts}/RainbowBorders.sh" >/dev/null 2>&1 &
fi

exit 0
