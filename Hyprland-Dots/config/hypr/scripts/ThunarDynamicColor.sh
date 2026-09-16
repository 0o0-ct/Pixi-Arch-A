#!/usr/bin/env bash
# Dynamic Folder Color Switcher for Thunar

PAPIRUS_BIN="$HOME/.local/bin/papirus-folders"
if ! command -v "$PAPIRUS_BIN" &>/dev/null; then
    PAPIRUS_BIN="papirus-folders"
fi

# Ensure Papirus-Dark is active GTK icon theme
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=Papirus-Dark/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
fi

if command -v "$PAPIRUS_BIN" &>/dev/null; then
    COLORS=("violet" "cyan" "indigo" "teal" "deeporange" "magenta" "red" "green" "pink" "nordic" "carmine" "yellow" "bluegrey")
    RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}
    "$PAPIRUS_BIN" -C "$RANDOM_COLOR" >/dev/null 2>&1
fi

# Launch Thunar
exec thunar "$@"
