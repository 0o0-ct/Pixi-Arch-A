#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Rofi menu para gestión de paletas favoritas

set -euo pipefail

SCRIPT_DIR="$HOME/.config/hypr/scripts"
MANAGER="$SCRIPT_DIR/PaletteManager.sh"

# Obtener lista de favoritas
get_favorites() {
    python3 -c "
import json
try:
    with open('$HOME/.config/pixi-colors/settings.json') as f:
        data = json.load(f)
    favs = data.get('favorite_palettes', {})
    for name in favs:
        print(name)
except:
    pass
"
}

# Menú principal
show_menu() {
    local favorites=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && favorites+=("$line")
    done < <(get_favorites)
    
    local options=(
        "🎨 Guardar paleta actual"
        "📋 Listar favoritas"
        "⚙️  Ver configuración actual"
        "🎯 Ver paleta actual"
    )
    
    for fav in "${favorites[@]}"; do
        options+=("🎨 Cargar: $fav")
        options+=("🎨 Mezclar: $fav (50%)")
        options+=("🗑️ Eliminar: $fav")
    done
    
    printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "🎨 Palette Manager" -theme ~/.config/rofi/wallust/colors-rofi.rasi
}

choice=$(show_menu)

case "$choice" in
    "🎨 Guardar paleta actual")
        name=$(rofi -dmenu -p "Nombre para la paleta" -theme ~/.config/rofi/wallust/colors-rofi.rasi)
        [[ -n "$name" ]] && "$MANAGER" save "$name"
        ;;
    "📋 Listar favoritas")
        "$MANAGER" list | rofi -dmenu -p "Favoritas" -theme ~/.config/rofi/wallust/colors-rofi.rasi
        ;;
    "⚙️  Ver configuración actual")
        "$MANAGER" settings | rofi -dmenu -p "Configuración" -theme ~/.config/rofi/wallust/colors-rofi.rasi
        ;;
    "🎯 Ver paleta actual")
        "$MANAGER" current | rofi -dmenu -p "Paleta Actual" -theme ~/.config/rofi/wallust/colors-rofi.rasi
        ;;
    "🎨 Cargar: "*|"🎨 Mezclar: "*|"🗑️ Eliminar: "*)
        action="${choice%%: *}"
        name="${choice#*: }"
        case "$action" in
            "🎨 Cargar") "$MANAGER" load "$name" ;;
            "🎨 Mezclar")
                weight=$(rofi -dmenu -p "Peso (0.0-1.0, actual=$weight)" -theme ~/.config/rofi/wallust/colors-rofi.rasi)
                [[ -n "$weight" ]] && "$MANAGER" blend "$name" "$weight"
                ;;
            "🗑️ Eliminar")
                confirm=$(echo -e "Sí\nNo" | rofi -dmenu -p "¿Eliminar '$name'?")
                [[ "$confirm" == "Sí" ]] && "$MANAGER" delete "$name"
                ;;
        esac
        ;;
esac