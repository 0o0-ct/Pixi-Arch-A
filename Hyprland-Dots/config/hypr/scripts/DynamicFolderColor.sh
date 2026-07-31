#!/usr/bin/env bash
# /* ---- 💫 Instant Dynamic Folder Color Manager for Nautilus 💫 ---- */

# 1. Launch Nautilus INSTANTLY (0ms delay)
nautilus --new-window "$@" &

# 2. Change folder colors completely silently in the background
(
    # Auto-install papirus-folders if missing on user system
    if [ ! -x "$HOME/.local/bin/papirus-folders" ]; then
        mkdir -p "$HOME/.local/bin" "$HOME/.local/share/icons"
        curl -sSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o "$HOME/.local/bin/papirus-folders" 2>/dev/null
        chmod +x "$HOME/.local/bin/papirus-folders" 2>/dev/null
    fi

    # Auto-install Papirus icon theme if missing
    if [ ! -d "$HOME/.local/share/icons/Papirus-Dark" ] && [ ! -d "/usr/share/icons/Papirus-Dark" ]; then
        curl -sSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-icon-theme/master/install.sh | DESTDIR="$HOME/.local/share/icons" sh >/dev/null 2>&1
    fi

    COLORS=(
        "cyan" "teal" "green" "nordic" "violet" "magenta" "indigo" 
        "carmine" "deeporange" "yellow" "bluegrey" "darkcyan" "yaru" "pink" "blue" "breeze"
    )
    RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}

    if [ -x "$HOME/.local/bin/papirus-folders" ]; then
        "$HOME/.local/bin/papirus-folders" -C "$RANDOM_COLOR" -t Papirus-Dark -o >/dev/null 2>&1
    fi
) &
