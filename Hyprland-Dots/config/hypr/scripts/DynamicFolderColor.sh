#!/usr/bin/env bash
# /* ---- 💫 Dynamic Folder Color Manager for Nautilus/Thunar 💫 ---- */

# List of rich Papirus folder colors
COLORS=(
    "cyan"
    "teal"
    "green"
    "nordic"
    "violet"
    "magenta"
    "indigo"
    "carmine"
    "deeporange"
    "yellow"
    "bluegrey"
    "darkcyan"
    "yaru"
    "pink"
    "blue"
    "breeze"
)

# Pick random color from array
RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}

# Change folder color using papirus-folders
if [ -x "$HOME/.local/bin/papirus-folders" ]; then
    "$HOME/.local/bin/papirus-folders" -C "$RANDOM_COLOR" -t Papirus-Dark >/dev/null 2>&1
fi

# Ensure GTK Icon Theme is set to Papirus-Dark
CURRENT_ICON=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
if [ "$CURRENT_ICON" != "Papirus-Dark" ]; then
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null
fi

# Send subtle notification
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u low -i folder -a "Archivos" "Color de Carpetas" "Cambiado dinámicamente a: ${RANDOM_COLOR^}"
fi

# Launch Nautilus with any passed arguments
exec nautilus --new-window "$@"
