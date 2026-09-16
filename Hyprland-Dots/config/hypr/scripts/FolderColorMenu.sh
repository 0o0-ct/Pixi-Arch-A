#!/usr/bin/env bash
# Rofi Menu to Select Papirus Folder Colors

COLORS=(
    "violet"
    "cyan"
    "indigo"
    "teal"
    "deeporange"
    "magenta"
    "red"
    "green"
    "pink"
    "nordic"
    "carmine"
    "yellow"
    "blue"
    "random"
)

CHOSEN=$(printf "%s\n" "${COLORS[@]}" | rofi -dmenu -i -p "📁 Color de Carpetas")

if [ -n "$CHOSEN" ]; then
    if [ "$CHOSEN" == "random" ]; then
        $HOME/.config/hypr/scripts/SetFolderColor.sh
        notify-send -u low "Carpetas:" "Color cambiado aleatoriamente"
    else
        $HOME/.config/hypr/scripts/SetFolderColor.sh "$CHOSEN"
        notify-send -u low "Carpetas:" "Color cambiado a $CHOSEN"
    fi
fi
