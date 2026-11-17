#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Dynamically symlink the correct hyprlock configuration based on active screen resolution.

focused_height=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .height' 2>/dev/null)
if [ -z "$focused_height" ] || [ "$focused_height" = "null" ]; then
    focused_height=$(hyprctl monitors | grep -B 10 -i "focused: yes" | grep -oE '[0-9]+x[0-9]+' | head -n 1 | cut -d'x' -f2)
fi
if [ -z "$focused_height" ]; then
    focused_height=1080
fi

CONFIG_DIR="$HOME/.config/hypr"
if [ ! -d "$CONFIG_DIR" ]; then
    exit 0
fi

if [ "$focused_height" -le 1080 ]; then
    ln -sf "$CONFIG_DIR/hyprlock-1080p.conf" "$CONFIG_DIR/hyprlock.conf"
elif [ "$focused_height" -le 1440 ]; then
    ln -sf "$CONFIG_DIR/hyprlock-2k.conf" "$CONFIG_DIR/hyprlock.conf"
elif [ "$focused_height" -le 2160 ]; then
    ln -sf "$CONFIG_DIR/hyprlock-4k.conf" "$CONFIG_DIR/hyprlock.conf"
else
    ln -sf "$CONFIG_DIR/hyprlock-8k.conf" "$CONFIG_DIR/hyprlock.conf"
fi
