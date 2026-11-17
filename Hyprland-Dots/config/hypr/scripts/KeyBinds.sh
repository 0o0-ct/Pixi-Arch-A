#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Buscador de atajos de teclado usando los binds vivos de Hyprland.

set -uo pipefail

rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='☣️ NOTA ☣️: Hacer clic con el ratón o pulsar ENTER NO tendrá función'

# Cerrar yad/rofi para no interferir
pkill yad >/dev/null 2>&1 || true
pkill rofi >/dev/null 2>&1 || true

friendly_key() {
    case "$1" in
        Return)       printf 'Enter' ;;
        space)        printf 'Espacio' ;;
        Print)        printf 'Impr Pant' ;;
        mouse:272)    printf 'clic izquierdo' ;;
        mouse:273)    printf 'clic derecho' ;;
        mouse_down)   printf 'rueda abajo' ;;
        mouse_up)     printf 'rueda arriba' ;;
        bracketleft)  printf '[' ;;
        bracketright) printf ']' ;;
        period)       printf '.' ;;
        comma)        printf ',' ;;
        *)            printf '%s' "$1" ;;
    esac
}

mods_label() {
    local mod="$1" label=""
    if (( mod & 64 )); then label+="SUPER + "; fi
    if (( mod & 4 ));  then label+="CTRL + "; fi
    if (( mod & 8 ));  then label+="ALT + "; fi
    if (( mod & 1 ));  then label+="SHIFT + "; fi
    printf '%s' "$label"
}

# Los binds Lua guardan la descripción en "description".
display_keybinds=$(
    hyprctl -j binds 2>/dev/null |
    jq -r '.[] | select(.description != null and .description != "") | "\(.modmask)\t\(.key)\t\(.description)"' |
    while IFS=$'\t' read -r mod key desc; do
        printf '%-34s %s\n' "$(mods_label "$mod")$(friendly_key "$key")" "$desc"
    done |
    sort -u
)

if [[ -z "$display_keybinds" ]]; then
    notify-send -u low "Atajos" "No se pudieron leer los atajos de Hyprland" 2>/dev/null || true
    exit 1
fi

printf '%s\n' "$display_keybinds" |
    rofi -dmenu -i -config "$rofi_theme" -mesg "$msg" -p "Atajos" >/dev/null

exit 0
