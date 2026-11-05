#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Aplica presets de animaciones Lua (Hyprland 0.57+)

set -uo pipefail

iDIR="$HOME/.config/swaync/images"
animations_dir="$HOME/.config/hypr/animations"
user_config="$HOME/.config/hypr/UserConfigs/UserAnimations.lua"
rofi_theme="$HOME/.config/rofi/config-Animations.rasi"
msg='❗NOTA:❗ El preset se guarda en UserAnimations.lua y se recarga Hyprland'

# Cerrar rofi si ya está abierto
pkill rofi >/dev/null 2>&1 || true

# Lista de presets .lua, ordenados
animations_list=$(find -L "$animations_dir" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' 2>/dev/null | sed 's/\.lua$//' | sort -V)

if [[ -z "$animations_list" ]]; then
    notify-send -u low -i "$iDIR/ja.png" "Animaciones" "No hay presets en $animations_dir" 2>/dev/null || true
    exit 1
fi

chosen_file=$(printf '%s\n' "$animations_list" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg" -p "Animaciones")

[[ -z "${chosen_file:-}" ]] && exit 0

full_path="$animations_dir/$chosen_file.lua"
if [[ ! -f "$full_path" ]]; then
    notify-send -u low -i "$iDIR/ja.png" "Animaciones" "Preset no encontrado: $chosen_file" 2>/dev/null || true
    exit 1
fi

mkdir -p "$(dirname "$user_config")"
cp -f "$full_path" "$user_config"

hyprctl reload >/dev/null 2>&1

notify-send -u low -i "$iDIR/ja.png" "$chosen_file" "Animaciones aplicadas" 2>/dev/null || true
