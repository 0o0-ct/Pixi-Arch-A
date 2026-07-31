#!/usr/bin/env bash
# /* ---- 💫 Instant Dynamic Folder Color Manager for Nautilus 💫 ---- */

# 1. Launch Nautilus INSTANTLY (0ms delay)
nautilus --new-window "$@" &

# 2. Change folder colors completely silently in the background (No notifications)
(
    COLORS=(
        "cyan" "teal" "green" "nordic" "violet" "magenta" "indigo" 
        "carmine" "deeporange" "yellow" "bluegrey" "darkcyan" "yaru" "pink" "blue" "breeze"
    )
    RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}

    if [ -x "$HOME/.local/bin/papirus-folders" ]; then
        "$HOME/.local/bin/papirus-folders" -C "$RANDOM_COLOR" -t Papirus-Dark -o >/dev/null 2>&1
    fi
) &
