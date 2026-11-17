#!/usr/bin/env bash
# /* ---- 🧠 prime-launch.sh — Lanzador inteligente de GPU dinámica 💫 ---- */
# Decide automáticamente si una aplicación debe ejecutarse con GPU NVIDIA dedicada
# o con la GPU integrada (Intel/AMD) según:
#   1. Base de datos de aplicaciones conocidas
#   2. Detección de monitor externo conectado
#   3. Perfil personalizado del usuario
#
# Uso:
#   prime-launch firefox          -> usa Intel (navegador ligero)
#   prime-launch steam            -> usa NVIDIA (juego)
#   prime-launch blender          -> usa NVIDIA (renderizado)
#   prime-launch --force-nvidia code  -> fuerza NVIDIA para VS Code
#   prime-launch --force-igpu steam  -> fuerza Intel para Steam
#
# Sin argumentos, muestra el estado actual de la GPU

set -euo pipefail

# ============================================================
# CONFIGURACIÓN
# ============================================================
APP_DB_FILE="$HOME/.config/hypr/scripts/gpu-app-db.conf"
CUSTOM_RULES_FILE="$HOME/.config/hypr/scripts/gpu-custom-rules.conf"
LOG_FILE="$HOME/.cache/prime-launch.log"
CHECK_INTERVAL=30  # segundos entre verificaciones de monitor

# ============================================================
# BASE DE DATOS DE APLICACIONES (integrada)
# ============================================================
# Si el archivo externo no existe, usa esta base de datos por defecto
DEFAULT_APP_DB='
# ============================================================
# APLICACIONES QUE REQUIEREN GPU DEDICADA (NVIDIA)
# Formato: app_name:razon
# ============================================================
# --- Juegos y Launchers ---
steam:launcher de juegos
heroic:launcher juegos open source
lutris:plataforma de juegos
minigalaxy:launcher GOG
steam-native:proceso Steam
%steam:proceso Steam genérico
heroine:launcher Heroic
gamescope:wayland gaming compositor
mangohud:overlay de monitoreo
# --- Motores de juego ---
unity:motor Unity
unreal:motor Unreal
godot:motor Godot
# --- 3D, Renderizado y Diseño ---
blender:renderizado 3D
blender.bin:renderizado 3D
kiri:modelado 3D
freecad:CAD
freeCAD:CAD
fusion:Onshape/Fusion 360
solidworks:CAD profesional
cinema:4D
maya:Autodesk Maya
3dsmax:Autodesk 3ds Max
houdini:SideFX Houdini
zbrush:esculpido 3D
substance:Adobe Substance
davinci:DaVinci Resolve video
resolve:DaVinci Resolve
premiere:Adobe Premiere video
aftereffects:Adobe After Effects
ae:Adobe After Effects
audition:Adobe Audition
lightroom:Adobe Lightroom
photoshop:Adobe Photoshop
illustrator:Adobe Illustrator
indesign:Adobe InDesign
# --- Video y Streaming ---
obs:streaming y grabación
obs64:streaming OBS
vkcapture:grabación Vulkan
kdenlive:edición video
shotcut:edición video
handbrake:transcodificación video
mpv:reproductor video (hardware accel)
vlc:reproductor multimedia
# --- BENCHMARKS Y TEST ---
unigine:benchmark gráfico
furmark:stress test GPU
heaven:benchmark Heaven
gtx:benchmark GTX
3dmark:benchmark 3DMark
glxgears:test OpenGL
glmark2:benchmark OpenGL
cinebench:benchmark CPU/GPU
# --- Machine Learning / AI ---
jupyter:notebooks ML
tensorboard:visualización ML
python:scripts Python (posible ML)
# --- Emuladores de consola (algunos requieren GPU) ---
yuzu:emulador Switch
ryujinx:emulador Switch
cemu:emulador Wii U
dolphin:emulador Wii/GameCube
rpcs3:emulador PS3
aetherux:emulador PS2
# ============================================================
# APLICACIONES LIGERAS (GPU INTEGRADA)
# Formato: app_name:razon
# ============================================================
# --- Navegadores ---
firefox:navegador web
librewolf:navegador web
chromium:navegador web
google-chrome:navegador web
brave-browser:navegador web
epiphany:navegador web
# --- Terminales ---
kitty:terminal
alacritty:terminal
foot:terminal
konsole:terminal
gnome-terminal:terminal
xfce4-terminal:terminal
tilix:terminal
# --- Editores de texto / IDEs ligeros ---
code:VS Code (ligero sin extensiones pesadas)
code-oss:VS Code OSS
vim:editor de texto
nvim:Neovim
nano:editor de texto
gedit:editor de texto
mousepad:editor de texto
leafpad:editor de texto
kate:editor KDE
subl:Sublime Text
atom:editor Atom
# --- Herramientas de sistema ---
thunar:file manager
nautilus:file manager
dolphin:file manager
pcmanfm:file manager
nemo:file manager
rox-filer:file manager
# --- Comunicaciones ---
discord:comunicación
slack:comunicación
telegram:comunicación
signal:comunicación
zoom:videollamadas
teams:Microsoft Teams
# --- Otros ---
rofi:launcher
wofi:launcher
fuzzel:launcher
hyprpaper:wallpaper
waybar:barra de estado
swaync:notificaciones
dunst:notificaciones
hyprlock:lockscreen
swaylock:lockscreen
loginctl:administración sistema
systemctl:administración sistema
paru:package manager
yay:package manager
pacman:package manager
'

# ============================================================
# FUNCIONES
# ============================================================

log_msg() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Detectar si hay monitor externo conectado
has_external_monitor() {
    # Detectar conectores externos activos (HDMI, DP, DisplayPort, VGA, DVI)
    local external_connectors="HDMI-A DP-1 DP-2 DP-3 DP-4 DP-5 HDMI-C DVI-I DVI-D VGA-1"
    
    for card in /sys/class/drm/card*/card*-*; do
        if [ -f "$card/status" ]; then
            local connector_name
            connector_name=$(basename "$(dirname "$card")")
            local status
            status=$(cat "$card/status" 2>/dev/null || echo "unknown")
            
            for ext in $external_connectors; do
                if [[ "$connector_name" == "$ext"* ]] && [ "$status" = "connected" ]; then
                    return 0
                fi
            done
        fi
    done
    
    # Método alternativo: contar displays conectados
    # Si hay más de 1 display, probablemente hay uno externo
    local connected_count=0
    for status_file in /sys/class/drm/card*-[A-Z][A-Z]-*/status; do
        if [ -f "$status_file" ]; then
            local st
            st=$(cat "$status_file" 2>/dev/null || echo "unknown")
            if [ "$st" = "connected" ]; then
                connected_count=$((connected_count + 1))
            fi
        fi
    done
    
    # Si hay 2 o más displays conectados, asumimos que hay uno externo
    if [ "$connected_count" -ge 2 ]; then
        return 0
    fi
    
    return 1
}

# Obtener uso actual de GPU NVIDIA
get_nvidia_usage() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' %' || echo "0"
    else
        echo "0"
    fi
}

# Obtener temperatura GPU NVIDIA
get_nvidia_temp() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' °C' || echo "0"
    else
        echo "0"
    fi
}

# Verificar si una app está en la lista de GPU dedicada
app_needs_dgpu() {
    local app_name="$1"
    local app_lower
    app_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
    
    # Construir la base de datos completa (default + custom)
    local full_db="$DEFAULT_APP_DB"
    if [ -f "$APP_DB_FILE" ]; then
        full_db+=$(cat "$APP_DB_FILE")
    fi
    if [ -f "$CUSTOM_RULES_FILE" ]; then
        full_db+=$(cat "$CUSTOM_RULES_FILE")
    fi
    
    # Buscar en la base de datos (ignorar comentarios y líneas vacías)
    echo "$full_db" | grep -v '^#' | grep -v '^$' | while IFS=: read -r db_name reason; do
        # Limpiar espacios
        db_name=$(echo "$db_name" | xargs)
        app_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | xargs)
        
        # Coincidencia exacta
        if [ "$app_lower" = "$db_name" ]; then
            return 0
        fi
        
        # Coincidencia parcial (contiene)
        if [[ "$app_lower" == *"$db_name"* ]] || [[ "$db_name" == *"$app_lower"* ]]; then
            return 0
        fi
        
        # Coincidencia con wildcard (%)
        if [[ "$db_name" == %* ]]; then
            local pattern="${db_name#\%}"
            if [[ "$app_lower" == *"$pattern"* ]]; then
                return 0
            fi
        fi
    done
    
    return 1
}

# Mostrar estado actual del sistema GPU
show_status() {
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           🧠 GPU Dinámica — Estado del Sistema           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    # GPU detectada
    echo "📊 GPU Detectada:"
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        echo "   NVIDIA: $gpu_name"
        echo "   Temperatura: $(get_nvidia_temp)°C"
        echo "   Uso GPU: $(get_nvidia_usage)%"
        echo "   VRAM Usada: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' | sed 's/MiB//') MiB"
        echo "   VRAM Total: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' | sed 's/MiB//') MiB"
    fi
    
    echo ""
    
    # Monitor externo
    echo "🖥️  Monitores:"
    if has_external_monitor; then
        echo "   ✅ Monitor externo detectado"
    else
        echo "   💻 Solo pantalla laptop (sin monitor externo)"
    fi
    
    echo ""
    
    # Procesos usando NVIDIA
    echo "🎮 Procesos usando GPU NVIDIA:"
    if command -v nvidia-smi >/dev/null 2>&1; then
        local processes
        processes=$(nvidia-smi pmon -c 1 2>/dev/null | tail -n +4 | grep -v "^$" || true)
        if [ -n "$processes" ]; then
            echo "$processes" | while read -r line; do
                echo "   $line"
            done
        else
            echo "   ✅ Ningún proceso usando NVIDIA (¡perfecto!)"
        fi
    fi
    
    echo ""
    echo "💡 Uso: prime-launch <aplicación> [--force-nvidia | --force-igpu]"
    echo "   prime-launch steam              -> NVIDIA (detectado automáticamente)"
    echo "   prime-launch firefox            -> Intel (detectado automáticamente)"
    echo "   prime-launch --force-nvidia code -> Fuerza NVIDIA"
    echo "   prime-launch --force-igpu blender -> Fuerza Intel"
}

# Mostrar ayuda
show_help() {
    echo "🧠 prime-launch.sh — Lanzador inteligente de GPU dinámica"
    echo ""
    echo "Uso:"
    echo "  prime-launch <aplicación> [argumentos...]"
    echo "  prime-launch --force-nvidia <aplicación> [argumentos...]"
    echo "  prime-launch --force-igpu <aplicación> [argumentos...]"
    echo "  prime-launch --status"
    echo "  prime-launch --help"
    echo ""
    echo "Ejemplos:"
    echo "  prime-launch steam              -> Usa NVIDIA (detectado)"
    echo "  prime-launch firefox            -> Usa Intel (detectado)"
    echo "  prime-launch --force-nvidia code -> Fuerza NVIDIA"
    echo "  prime-launch --force-igpu blender -> Fuerza Intel"
    echo ""
    echo "Reglas personalizadas:"
    echo "  Edita $CUSTOM_RULES_FILE"
    echo "  Formato: app_name:razon"
    echo ""
    echo "Base de datos integrada incluye:"
    echo "  Juegos: Steam, Heroic, Lutris, emuladores..."
    echo "  3D/Render: Blender, Maya, Cinema 4D..."
    echo "  Video: OBS, DaVinci Resolve, Premiere..."
    echo "  Benchmarks: Unigine, 3DMark, Cinebench..."
    echo "  ML/AI: Jupyter, TensorBoard..."
}

# ============================================================
# LÓGICA PRINCIPAL
# ============================================================

# Sin argumentos -> mostrar estado
if [ $# -eq 0 ]; then
    show_status
    exit 0
fi

# Flags
FORCE_NVIDIA=0
FORCE_IGPU=0
APP_NAME=""
shift_on_flag=0

# Parsear argumentos
case "$1" in
    --status|-s)
        show_status
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    --force-nvidia|--nvidia)
        FORCE_NVIDIA=1
        shift
        ;;
    --force-igpu|--igpu)
        FORCE_IGPU=1
        shift
        ;;
esac

# Verificar que hay un comando
if [ $# -eq 0 ]; then
    echo "❌ Error: No se especificó aplicación"
    show_help
    exit 1
fi

APP_NAME="$1"
shift

# ============================================================
# DECISIÓN DE GPU
# ============================================================

USE_NVIDIA=0

if [ "$FORCE_NVIDIA" -eq 1 ]; then
    USE_NVIDIA=1
    log_msg "FORZADO NVIDIA: $APP_NAME"
elif [ "$FORCE_IGPU" -eq 1 ]; then
    USE_NVIDIA=0
    log_msg "FORZADO iGPU: $APP_NAME"
else
    # Detección automática
    if app_needs_dgpu "$APP_NAME"; then
        USE_NVIDIA=1
        log_msg "AUTO NVIDIA: $APP_NAME (detectado en DB)"
    elif has_external_monitor; then
        # Si hay monitor externo, ser más conservador
        # Solo usar NVIDIA si la app está en la lista
        USE_NVIDIA=0
        log_msg "AUTO iGPU: $APP_NAME (monitor externo, app no en lista)"
    else
        # Solo laptop, sin monitor externo -> iGPU por defecto
        USE_NVIDIA=0
        log_msg "AUTO iGPU: $APP_NAME (laptop sin monitor externo)"
    fi
fi

# ============================================================
# EJECUCIÓN
# ============================================================

# Verificar que el comando existe
if ! command -v "$APP_NAME" >/dev/null 2>&1; then
    echo "⚠️  Advertencia: '$APP_NAME' no encontrado en PATH"
    echo "   Intentando ejecutar de todas formas..."
fi

if [ "$USE_NVIDIA" -eq 1 ]; then
    GPU_LABEL="🟢 NVIDIA"
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    
    echo "$GPU_LABEL → Ejecutando '$APP_NAME' con GPU NVIDIA dedicada"
    log_msg "EJECUTANDO NVIDIA: $APP_NAME con args: $*"
    
    # Ejecutar con prime-run si está disponible, sino con variables
    if command -v prime-run >/dev/null 2>&1; then
        exec prime-run "$APP_NAME" "$@"
    else
        exec "$APP_NAME" "$@"
    fi
else
    GPU_LABEL="🔵 Intel/AMD"
    # Asegurar que NO se use NVIDIA
    unset __NV_PRIME_RENDER_OFFLOAD 2>/dev/null || true
    unset __NV_PRIME_RENDER_OFFLOAD_PROVIDER 2>/dev/null || true
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    
    echo "$GPU_LABEL → Ejecutando '$APP_NAME' con GPU integrada"
    log_msg "EJECUTANDO iGPU: $APP_NAME con args: $*"
    
    exec "$APP_NAME" "$@"
fi
