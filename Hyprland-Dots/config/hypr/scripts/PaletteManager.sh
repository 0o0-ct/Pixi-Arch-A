#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Palette Manager - CLI para gestionar paletas favoritas y previsualización
# Uso: PaletteManager.sh [list|save|load|delete|preview|blend] [name]

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

ENGINE="$HOME/.config/hypr/scripts/pixi_colors.py"
SETTINGS_FILE="$HOME/.config/pixi-colors/settings.json"
CACHE_ROOT="$HOME/.cache/pixi-colors"

usage() {
    cat <<EOF
🎨 Pixi-Arch-A Palette Manager

Uso: $0 <comando> [argumentos]

Comandos:
  list                    Listar todas las paletas guardadas
  save <nombre>           Guardar paleta actual como favorita
  load <nombre>           Cargar una paleta favorita
  delete <nombre>         Eliminar una paleta favorita
  preview <nombre>        Previsualizar paleta (genera CSS temporal)
  blend <nombre> [peso]   Mezclar paleta actual con favorita (0.0-1.0)
  current                 Mostrar paleta actual en uso
  settings                Mostrar configuración actual
  export <nombre> <file>  Exportar paleta a archivo JSON
  import <file>           Importar paleta desde archivo

Ejemplos:
  $0 list
  $0 save "mi-atardecer"
  $0 load "mi-atardecer"
  $0 blend "mi-atardecer" 0.3
  $0 current
EOF
}

have_notify() { command -v notify-send >/dev/null 2>&1; }
notify() { have_notify && notify-send -a "PaletteManager" "$@"; }

cmd_list() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo "No hay configuración aún. Cambia el wallpaper primero."
        return 1
    fi
    
    python3 -c "
import json
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    favs = data.get('favorite_palettes', {})
    if not favs:
        print('No hay paletas favoritas guardadas.')
    else:
        print('Paletas favoritas:')
        for name, info in favs.items():
            ts = info.get('timestamp', 'unknown')
            mode = info.get('settings', {}).get('mode', 'dark')
            scheme = info.get('settings', {}).get('scheme', 'auto')
            glass = info.get('settings', {}).get('glass', 'auto')
            print(f'  ✨ {name}')
            print(f'     Mode: {mode} | Scheme: {scheme} | Glass: {glass}')
            print(f'     Guardada: {ts}')
            print()
except Exception as e:
    print(f'Error: {e}')
"
}

cmd_save() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Uso: $0 save <nombre>"
        return 1
    fi
    
    # Verificar que hay una paleta actual
    if [[ ! -f "$CACHE_ROOT/last-run.json" ]]; then
        echo "No hay paleta actual. Cambia el wallpaper primero."
        return 1
    fi
    
    python3 "$ENGINE" --save-favorite "$name" && \
        notify "Paleta guardada" "✨ '$name' añadida a favoritos" || \
        notify -u critical "Error" "No se pudo guardar la paleta"
}

cmd_load() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Uso: $0 load <nombre>"
        return 1
    fi
    
    python3 "$ENGINE" --load-favorite "$name" && \
        notify "Paleta cargada" "✨ '$name' aplicada" || \
        notify -u critical "Error" "No se pudo cargar la paleta"
}

cmd_delete() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Uso: $0 delete <nombre>"
        return 1
    fi
    
    python3 "$ENGINE" --delete-favorite "$name" && \
        notify "Paleta eliminada" "🗑️ '$name' removida" || \
        notify -u critical "Error" "No se pudo eliminar"
}

cmd_current() {
    if [[ ! -f "$CACHE_ROOT/last-run.json" ]]; then
        echo "No hay paleta actual."
        return 1
    fi
    
    python3 -c "
import json
try:
    with open('$CACHE_ROOT/last-run.json') as f:
        data = json.load(f)
    if data.get('status') != 'ok':
        print('Última ejecución falló:', data.get('errors', ['desconocido']))
        return
    
    print('🎨 Paleta actual:')
    print(f\"  Wallpaper: {data.get('wallpaper', 'N/A')}\")
    print(f\"  Mode: {data.get('mode', 'dark')}\")
    print(f\"  Scheme: {data.get('scheme', 'auto')}\")
    print(f\"  Glass: {data.get('glass', 'auto')}\")
    print(f\"  Cache: {'hit' if data.get('cache_hit') else 'miss'}\")
    print(f\"  Duración: {data.get('duration_ms', 0)}ms\")
    print(f\"  Generación: {data.get('generation', 'N/A')}\")
    
    palette = data.get('palette', {})
    if palette:
        print()
        print('  Colores ANSI:')
        for k in ['background', 'foreground', 'color0', 'color1', 'color2', 'color3', 'color4', 'color5', 'color6', 'color7']:
            if k in palette:
                print(f'    {k}: {palette[k]}')
    
    m3 = data.get('m3', {})
    if m3:
        print()
        print('  Roles Material 3 (primeros 10):')
        for k in list(m3.keys())[:10]:
            print(f'    {k}: {m3[k]}')
        print(f'    ... y {len(m3) - 10} más')
        
except Exception as e:
    print(f'Error: {e}')
"
}

cmd_settings() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo "No hay configuración. Se usará la por defecto."
        return 1
    fi
    
    python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
print('⚙️ Configuración actual:')
for k, v in data.items():
    if k != 'favorite_palettes':
        print(f'  {k}: {v}')
favs = data.get('favorite_palettes', {})
print(f'  favorite_palettes: {len(favs)} guardadas')
"
}

cmd_export() {
    local name="$1"
    local file="$2"
    if [[ -z "$name" || -z "$file" ]]; then
        echo "Uso: $0 export <nombre> <archivo.json>"
        return 1
    fi
    
    python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
favs = data.get('favorite_palettes', {})
if '$name' not in favs:
    print('Paleta no encontrada:', '$name')
    exit(1)
with open('$file', 'w') as f:
    json.dump(favs['$name'], f, indent=2)
print(f'Exportado a $file')
"
}

cmd_import() {
    local file="$1"
    if [[ -z "$file" || ! -f "$file" ]]; then
        echo "Uso: $0 import <archivo.json>"
        return 1
    fi
    
    name=$(basename "$file" .json)
    python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    settings = json.load(f)
with open('$file') as f:
    pal = json.load(f)
settings.setdefault('favorite_palettes', {})['$name'] = pal
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
print(f'Importado como: $name')
"
}

cmd_blend() {
    local name="$1"
    local weight="${2:-0.5}"
    if [[ -z "$name" ]]; then
        echo "Uso: $0 blend <nombre> [peso 0.0-1.0]"
        return 1
    fi
    
    # Verificar que hay paleta actual y favorita
    if [[ ! -f "$CACHE_ROOT/last-run.json" ]]; then
        echo "No hay paleta actual."
        return 1
    fi
    
    python3 -c "
import json
with open('$CACHE_ROOT/last-run.json') as f:
    current = json.load(f)
with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

favs = settings.get('favorite_palettes', {})
if '$name' not in favs:
    print('Favorita no encontrada:', '$name')
    exit(1)

fav = favs['$name']
current_pal = current.get('palette', {})
fav_pal = fav.get('wallust', {})

weight = $weight
if weight < 0 or weight > 1:
    print('Peso debe ser 0.0-1.0')
    exit(1)

def blend_hex(a, b, w):
    ar, ag, ab = int(a[1:3],16), int(a[3:5],16), int(a[5:7],16)
    br, bg, bb = int(b[1:3],16), int(b[3:5],16), int(b[5:7],16)
    r = round(ar * w + br * (1-w))
    g = round(ag * w + bg * (1-w))
    b = round(ab * w + bb * (1-w))
    return f'#{r:02x}{g:02x}{b:02x}'

blended = {}
for k in current_pal:
    if k in fav_pal:
        blended[k] = blend_hex(current_pal[k], fav_pal[k], weight)
    else:
        blended[k] = current_pal[k]

# Guardar como temporal y aplicar
import tempfile
with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
    json.dump({'palette': blended, 'm3': current.get('m3', {})}, f)
    tmp = f.name

print(f'Paleta mezclada (peso actual: {weight}): {tmp}')
print('Para aplicarla, usa: pixi_colors.py con la paleta mezclada')
"
}

case "${1:-}" in
    list) cmd_list ;;
    save) cmd_save "${2:-}" ;;
    load) cmd_load "${2:-}" ;;
    delete) cmd_delete "${2:-}" ;;
    current) cmd_current ;;
    settings) cmd_settings ;;
    export) cmd_export "${2:-}" "${3:-}" ;;
    import) cmd_import "${2:-}" ;;
    blend) cmd_blend "${2:-}" "${3:-}" ;;
    *) usage; exit 1 ;;
esac