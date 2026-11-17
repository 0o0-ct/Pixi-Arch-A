#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Interactive Rofi or CLI Papirus Folder Color Changer

PAPIRUS_BIN="$HOME/.local/bin/papirus-folders"
if ! command -v "$PAPIRUS_BIN" &>/dev/null; then
    PAPIRUS_BIN="papirus-folders"
fi

if ! command -v "$PAPIRUS_BIN" &>/dev/null; then
    notify-send "Papirus Folders" "papirus-folders no está instalado." -i dialog-error 2>/dev/null || true
    exit 1
fi

COLORS=("blue" "bluegrey" "breeze" "carmine" "cyan" "darkcyan" "deeporange" "green" "grey" "indigo" "magenta" "nordic" "orange" "pink" "red" "teal" "violet" "yellow")

if [[ -n "${1:-}" ]]; then
    CHOICE="$1"
else
    # Si no se pasó argumento, mostrar menú interactivo en Rofi
    rofi_theme="$HOME/.config/rofi/config.rasi"
    if [[ -f "$rofi_theme" ]]; then
        CHOICE=$(printf '%s\n' "${COLORS[@]}" | rofi -dmenu -i -p "📁 Color de Carpetas" -theme "$rofi_theme")
    else
        CHOICE=$(printf '%s\n' "${COLORS[@]}" | rofi -dmenu -i -p "📁 Color de Carpetas")
    fi
fi

if [[ -n "$CHOICE" ]]; then
    "$PAPIRUS_BIN" -C "$CHOICE" >/dev/null 2>&1
    notify-send -u low -i "folder" "Color de Carpetas" "Carpetas cambiadas al color: $CHOICE" 2>/dev/null || true
fi
