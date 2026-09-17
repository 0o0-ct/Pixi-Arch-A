#!/usr/bin/env bash
# 💫 Pixi-Arch-A Smart Multi-Monitor Dock Manager 💫

pkill -f nwg-dock-hyprland 2>/dev/null || true
sleep 0.3

# Get list of connected monitors
if command -v jq &>/dev/null && command -v hyprctl &>/dev/null; then
    MONITORS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
fi

if [ -n "$MONITORS" ]; then
    for MON in $MONITORS; do
        nohup nwg-dock-hyprland -m -o "$MON" -i 36 -mb 10 -ml 10 -mr 10 -a center -d -c "pkill rofi || rofi -show drun" >/dev/null 2>&1 &
    done
else
    nohup nwg-dock-hyprland -i 36 -mb 10 -ml 10 -mr 10 -a center -d -c "pkill rofi || rofi -show drun" >/dev/null 2>&1 &
fi
