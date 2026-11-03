#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# For disabling touchpad.
# Edit the Touchpad_Device on ~/.config/hypr/UserConfigs/Laptops.conf according to your system
# use hyprctl devices to get your system touchpad device name
# source https://github.com/hyprwm/Hyprland/discussions/4283?sort=new#discussioncomment-8648109

set -euo pipefail

notif="$HOME/.config/swaync/images/ja.png"
laptops_conf="$HOME/.config/hypr/UserConfigs/Laptops.conf"

touchpad_device="${TOUCHPAD_DEVICE:-}"
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '/^\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$laptops_conf"
    )"
fi

# Fallback: detectar automáticamente el touchpad del sistema
if [[ -z "$touchpad_device" ]] && command -v jq >/dev/null 2>&1; then
    touchpad_device="$(
        hyprctl devices -j 2>/dev/null \
            | jq -r '.mice[]? | select(.name | test("touchpad"; "i")) | .name' \
            | head -n1
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    notify-send -u low -i "$notif" " Touchpad" " No se detectó ningún touchpad (define \$Touchpad_Device en Laptops.conf)"
    exit 1
fi

status_file="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"

enable_touchpad() {
    printf "true" >"$status_file"
    notify-send -u low -i "$notif" " Habilitando" " touchpad"
    hyprctl eval "hl.device({ name = \"$touchpad_device\", enabled = true })" >/dev/null 2>&1
}

disable_touchpad() {
    printf "false" >"$status_file"
    notify-send -u low -i "$notif" " Deshabilitando" " touchpad"
    hyprctl eval "hl.device({ name = \"$touchpad_device\", enabled = false })" >/dev/null 2>&1
}

current_state="false"
if [[ -f "$status_file" ]]; then
    current_state="$(<"$status_file")"
fi

if [[ "$current_state" == "true" ]]; then
    disable_touchpad
else
    enable_touchpad
fi
