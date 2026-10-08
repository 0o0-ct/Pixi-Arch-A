#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Script maestro de optimización Pixi-Arch-A
# Uso: optimize.sh [--dry-run] [--profile=performance|balanced|quality] [--apply] [--rollback] [--benchmark]

set -euo pipefail

# Configuración
LOG_DIR="$HOME/.cache/pixi-arch"
LOG_FILE="$LOG_DIR/optimize.log"
BACKUP_DIR="$HOME/.config/hypr.bak-$(date +%F)"
PERF_PROFILE_FILE="$HOME/.config/hypr/UserConfigs/PerformanceProfile.conf"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
APPLY=false
ROLLBACK=false
BENCHMARK=false
TARGET_PROFILE=""

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Función de logging
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }
success() { log "SUCCESS" "$@"; }

# Ejecutar comando (respetando --dry-run)
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN]${NC} $*" | tee -a "$LOG_FILE"
    else
        eval "$*" 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Verificar si comando existe
cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --apply)
            APPLY=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --benchmark)
            BENCHMARK=true
            shift
            ;;
        --profile=*)
            TARGET_PROFILE="${1#*=}"
            shift
            ;;
        --profile)
            TARGET_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            cat <<EOF
Uso: $0 [OPCIONES]

Opciones:
  --dry-run           Mostrar qué se haría sin ejecutar (por defecto)
  --apply             Aplicar cambios reales
  --rollback          Restaurar backup más reciente
  --benchmark         Ejecutar benchmark antes/después
  --profile=PERFIL    Cambiar perfil de rendimiento (performance|balanced|quality)
  -h, --help          Mostrar esta ayuda

Ejemplos:
  $0 --dry-run                    # Ver qué pasaría (por defecto)
  $0 --apply --profile=balanced   # Aplicar con perfil balanced
  $0 --benchmark                  # Benchmark sin cambios
  $0 --rollback                   # Restaurar backup
EOF
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            exit 1
            ;;
    esac
done

# Por defecto es dry-run si no se especifica --apply
if [ "$APPLY" = false ] && [ "$ROLLBACK" = false ] && [ "$BENCHMARK" = false ] && [ -z "$TARGET_PROFILE" ]; then
    DRY_RUN=true
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Pixi-Arch-A Optimization Engine v1.0             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠ MODO DRY-RUN: No se aplicarán cambios reales${NC}"
    echo ""
fi

# ============================================================
# ROLLBACK
# ============================================================
if [ "$ROLLBACK" = true ]; then
    info "Iniciando rollback..."
    if [ -d "$HOME/.config/hypr.bak-$(date +%F)" ]; then
        BACKUP_DIR="$HOME/.config/hypr.bak-$(date +%F)"
    else
        BACKUP_DIR=$(ls -dt ~/.config/hypr.bak-* 2>/dev/null | head -1)
    fi
    
    if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
        error "No hay backups disponibles en ~/.config/hypr.bak-*"
        exit 1
    fi
    
    info "Restaurando desde: $BACKUP_DIR"
    run_cmd "rm -rf ~/.config/hypr"
    run_cmd "cp -r '$BACKUP_DIR' ~/.config/hypr"
    success "Rollback completado. Reinicia Hyprland (SUPER+SHIFT+R) o relógate."
    exit 0
fi

# ============================================================
# BENCHMARK
# ============================================================
if [ "$BENCHMARK" = true ]; then
    info "Ejecutando benchmark..."
    
    # Info de monitores
    echo -e "\n${BLUE}=== Monitores ===${NC}" | tee -a "$LOG_FILE"
    hyprctl -j monitors | jq -r '.[] | "\(.name): \(.width)x\(.height)@\(.refreshRate)Hz \(.scale)x"' | tee -a "$LOG_FILE"
    
    # GPU info
    echo -e "\n${BLUE}=== GPU ===${NC}" | tee -a "$LOG_FILE"
    glxinfo -B 2>/dev/null | grep -E "(OpenGL renderer|OpenGL version|Device:)" | tee -a "$LOG_FILE" || echo "glxinfo no disponible"
    
    # FPS test (glxgears 5 segundos)
    if cmd_exists glxgears; then
        echo -e "\n${BLUE}=== glxgears (5s) ===${NC}" | tee -a "$LOG_FILE"
        timeout 5 glxgears -info 2>&1 | tail -1 | tee -a "$LOG_FILE" || true
    fi
    
    # Memoria
    echo -e "\n${BLUE}=== Memoria ===${NC}" | tee -a "$LOG_FILE"
    free -h | tee -a "$LOG_FILE"
    
    # Hyprland version
    echo -e "\n${BLUE}=== Hyprland ===${NC}" | tee -a "$LOG_FILE"
    hyprctl version | head -3 | tee -a "$LOG_FILE"
    
    success "Benchmark completado. Ver $LOG_FILE"
    exit 0
fi

# ============================================================
# CAMBIAR PERFIL DE RENDIMIENTO
# ============================================================
if [ -n "$TARGET_PROFILE" ]; then
    if [[ ! "$TARGET_PROFILE" =~ ^(performance|balanced|quality)$ ]]; then
        error "Perfil inválido: $TARGET_PROFILE. Use: performance, balanced, quality"
        exit 1
    fi
    
    info "Cambiando perfil a: $TARGET_PROFILE"
    
    # Generar PerformanceProfile.conf completo según el perfil
    generate_performance_profile() {
        local profile="$1"
        local outfile="$2"
        
        case "$profile" in
            performance)
                cat > "$outfile" << 'EOF'
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Performance Profile — Controla blur, sombras, animaciones y apps de inicio
# PERFIL: performance (hardware modesto / VM / batería crítica)

$PERF_PROFILE = performance

# Blur: DESACTIVADO
$BLUR_ENABLED = 0
$BLUR_SIZE = 4
$BLUR_PASSES = 1
$BLUR_VIBRANCY = 0.0
$BLUR_CONTRAST = 0.90
$BLUR_BRIGHTNESS = 0.95

# Shadows: DESACTIVADAS
$SHADOW_ENABLED = 0
$SHADOW_RANGE = 8
$SHADOW_RENDER_POWER = 1

# Animations: MÍNIMAS (solo workspace)
$ANIM_BORDER_ENABLED = 0
$ANIM_WINDOW_ENABLED = 0
$ANIM_SPEED_FACTOR = 0.5
$BASE_WIN_SPEED = 3
$BASE_WIN_IN_SPEED = 3
$BASE_WIN_OUT_SPEED = 2
$BASE_WIN_MOVE_SPEED = 3
$BASE_BORDER_SPEED = 1
$BASE_FADE_SPEED = 2
$BASE_WS_SPEED = 3

# Startup Apps: SOLO ESENCIALES
$START_AGS = 0
$START_OVERVIEW = 0
EOF
                ;;
            balanced)
                cat > "$outfile" << 'EOF'
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Performance Profile — Controla blur, sombras, animaciones y apps de inicio
# PERFIL: balanced (por defecto - equilibrio visual/rendimiento)

$PERF_PROFILE = balanced

# Blur: MODERADO
$BLUR_ENABLED = 1
$BLUR_SIZE = 8
$BLUR_PASSES = 1
$BLUR_VIBRANCY = 0.0
$BLUR_CONTRAST = 0.90
$BLUR_BRIGHTNESS = 0.95

# Shadows: MODERADAS
$SHADOW_ENABLED = 1
$SHADOW_RANGE = 12
$SHADOW_RENDER_POWER = 2

# Animations: ESTÁNDAR
$ANIM_BORDER_ENABLED = 1
$ANIM_WINDOW_ENABLED = 0
$ANIM_SPEED_FACTOR = 1.0
$BASE_WIN_SPEED = 6
$BASE_WIN_IN_SPEED = 5
$BASE_WIN_OUT_SPEED = 3
$BASE_WIN_MOVE_SPEED = 5
$BASE_BORDER_SPEED = 1
$BASE_FADE_SPEED = 3
$BASE_WS_SPEED = 5

# Startup Apps: TODAS
$START_AGS = 1
$START_OVERVIEW = 1
EOF
                ;;
            quality)
                cat > "$outfile" << 'EOF'
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Performance Profile — Controla blur, sombras, animaciones y apps de inicio
# PERFIL: quality (GPU potente - máxima calidad visual)

$PERF_PROFILE = quality

# Blur: COMPLETO (glassmorphism)
$BLUR_ENABLED = 1
$BLUR_SIZE = 12
$BLUR_PASSES = 2
$BLUR_VIBRANCY = 0.30
$BLUR_CONTRAST = 0.95
$BLUR_BRIGHTNESS = 0.90

# Shadows: COMPLETAS
$SHADOW_ENABLED = 1
$SHADOW_RANGE = 20
$SHADOW_RENDER_POWER = 3

# Animations: COMPLETAS
$ANIM_BORDER_ENABLED = 1
$ANIM_WINDOW_ENABLED = 1
$ANIM_SPEED_FACTOR = 1.5
$BASE_WIN_SPEED = 9
$BASE_WIN_IN_SPEED = 8
$BASE_WIN_OUT_SPEED = 5
$BASE_WIN_MOVE_SPEED = 8
$BASE_BORDER_SPEED = 2
$BASE_FADE_SPEED = 5
$BASE_WS_SPEED = 8

# Startup Apps: TODAS + live wallpaper opcional
$START_AGS = 1
$START_OVERVIEW = 1
EOF
                ;;
        esac
    }
    
    run_cmd "generate_performance_profile '$TARGET_PROFILE' '$PERF_PROFILE_FILE'"
    
    if [ "$DRY_RUN" = false ]; then
        success "Perfil cambiado a $TARGET_PROFILE. Recarga Hyprland (SUPER+SHIFT+R) para aplicar."
        run_cmd "hyprctl reload"
    fi
    exit 0
fi

# ============================================================
# APLICAR OPTIMIZACIONES COMPLETAS (--apply)
# ============================================================
if [ "$APPLY" = true ]; then
    info "=== INICIANDO OPTIMIZACIÓN COMPLETA ==="
    
    # 1. Backup
    info "Creando backup en $BACKUP_DIR"
    run_cmd "cp -r ~/.config/hypr '$BACKUP_DIR'"
    
    # 2. Ejecutar detect-gpu.sh
    info "Ejecutando detección de GPU..."
    run_cmd "$HOME/.config/hypr/scripts/detect-gpu.sh"
    
    # 3. Verificar archivos generados
    info "Verificando configuración generada..."
    if [ -f "$HOME/.config/hypr/configs/ENVariables_GPU.conf" ]; then
        cat "$HOME/.config/hypr/configs/ENVariables_GPU.conf" | tee -a "$LOG_FILE"
    fi
    
    # 4. Verificar PerformanceProfile.conf
    if [ -f "$PERF_PROFILE_FILE" ]; then
        info "PerformanceProfile.conf actual:"
        cat "$PERF_PROFILE_FILE" | tee -a "$LOG_FILE"
    fi
    
    # 5. Swappiness dinámico (requiere sudo)
    RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
    if [ "$RAM_GB" -lt 8 ]; then
        SWAPPINESS=60
    elif [ "$RAM_GB" -ge 16 ]; then
        SWAPPINESS=10
    else
        SWAPPINESS=40
    fi
    
    info "RAM detectada: ${RAM_GB}GB → swappiness recomendado: $SWAPPINESS"
    echo -e "${YELLOW}Para aplicar swappiness (requiere sudo):${NC}"
    echo "  sudo sysctl -w vm.swappiness=$SWAPPINESS"
    echo "  echo 'vm.swappiness=$SWAPPINESS' | sudo tee /etc/sysctl.d/99-pixi-swappiness.conf"
    echo ""
    echo -e "${YELLOW}¿Aplicar swappiness=$SWAPPINESS ahora? [s/N]${NC}"
    read -r -t 10 REPLY || REPLY="n"
    if [[ "$REPLY" =~ ^[Ss]$ ]]; then
        run_cmd "sudo sysctl -w vm.swappiness=$SWAPPINESS"
        run_cmd "echo 'vm.swappiness=$SWAPPINESS' | sudo tee /etc/sysctl.d/99-pixi-swappiness.conf"
        success "Swappiness aplicado."
    else
        info "Swappiness no aplicado (puedes hacerlo manualmente después)."
    fi
    
    # 6. NVIDIA Dynamic Power Management (solo laptop híbrido Turing+)
    if [ -n "$(lspci -nn | grep -Ei 'nvidia')" ] && [ -d /sys/class/power_supply/BAT0 ]; then
        info "Laptop híbrido NVIDIA detectado. Verificando Dynamic Power Management..."
        if [ -f /etc/modprobe.d/nvidia-power.conf ]; then
            info "Ya existe /etc/modprobe.d/nvidia-power.conf"
        else
            echo -e "${YELLOW}¿Crear /etc/modprobe.d/nvidia-power.conf para Dynamic Power Management? [s/N]${NC}"
            echo "  options nvidia NVreg_DynamicPowerManagement=0x02"
            read -r -t 10 REPLY || REPLY="n"
            if [[ "$REPLY" =~ ^[Ss]$ ]]; then
                run_cmd "echo 'options nvidia NVreg_DynamicPowerManagement=0x02' | sudo tee /etc/modprobe.d/nvidia-power.conf"
                run_cmd "sudo mkinitcpio -P"
                warn "Se requiere reinicio para aplicar."
            fi
        fi
    fi
    
    # 7. Limpieza wallust cache con aviso
    WALLUST_CACHE="$HOME/.cache/wallust"
    if [ -d "$WALLUST_CACHE" ]; then
        CACHE_SIZE=$(du -sh "$WALLUST_CACHE" 2>/dev/null | cut -f1)
        info "Caché wallust: $CACHE_SIZE"
        if [ "$(du -s "$WALLUST_CACHE" 2>/dev/null | cut -f1)" -gt 1048576 ]; then
            warn "Caché wallust > 1GB. Posible bug en generador de temas."
            echo -e "${YELLOW}¿Limpiar caché wallust? (el primer cambio de wallpaper será más lento) [s/N]${NC}"
            read -r -t 10 REPLY || REPLY="n"
            if [[ "$REPLY" =~ ^[Ss]$ ]]; then
                run_cmd "rm -rf '$WALLUST_CACHE'"
                success "Caché wallust limpiada."
            fi
        fi
    fi
    
    # 8. Recargar Hyprland
    if [ "$DRY_RUN" = false ]; then
        info "Recargando Hyprland..."
        run_cmd "hyprctl reload"
        success "Hyprland recargado."
    fi
    
    success "=== OPTIMIZACIÓN COMPLETADA ==="
    echo -e "${GREEN}Log guardado en: $LOG_FILE${NC}"
    echo -e "${GREEN}Backup en: $BACKUP_DIR${NC}"
    echo -e "${GREEN}Rollback: ~/.config/hypr/restore.sh${NC}"
    exit 0
fi

# ============================================================
# DEFAULT: DRY-RUN COMPLETO
# ============================================================
info "=== DRY-RUN: Análisis del sistema ==="

# Hardware detection
echo -e "\n${BLUE}=== Hardware Detectado ===${NC}" | tee -a "$LOG_FILE"
lspci -nn | grep -Ei 'vga|3d|display' | tee -a "$LOG_FILE"
echo "RAM: $(free -h | awk '/Mem:/ {print $2}')" | tee -a "$LOG_FILE"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)" | tee -a "$LOG_FILE"
systemd-detect-virt | tee -a "$LOG_FILE" || echo "No VM"

# GPU detection test
echo -e "\n${BLUE}=== Simulación detect-gpu.sh ===${NC}" | tee -a "$LOG_FILE"
bash -n "$HOME/.config/hypr/scripts/detect-gpu.sh" && echo "Syntax OK" | tee -a "$LOG_FILE"

# Current configs
echo -e "\n${BLUE}=== Configuración Actual ===${NC}" | tee -a "$LOG_FILE"
echo "Performance Profile:" | tee -a "$LOG_FILE"
grep '^\$PERF_PROFILE' "$PERF_PROFILE_FILE" 2>/dev/null | tee -a "$LOG_FILE" || echo "  No configurado" | tee -a "$LOG_FILE"

echo -e "\n${BLUE}=== Recomendaciones ===${NC}" | tee -a "$LOG_FILE"
RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if [ "$RAM_GB" -ge 16 ]; then
    echo "  ✓ RAM >= 16GB: swappiness=10 recomendado" | tee -a "$LOG_FILE"
    echo "  ✓ Perfil 'quality' viable (32GB detectado)" | tee -a "$LOG_FILE"
fi

if lspci -nn | grep -qi nvidia; then
    echo "  ✓ NVIDIA detectada: detect-gpu.sh configurará offload híbrido" | tee -a "$LOG_FILE"
fi

if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
    echo "  ✓ Laptop: nm-applet y blueman-applet necesarios" | tee -a "$LOG_FILE"
fi

echo -e "\n${YELLOW}Para aplicar: $0 --apply${NC}"
echo -e "${YELLOW}Para cambiar perfil: $0 --apply --profile=quality${NC}"
echo -e "${YELLOW}Para benchmark: $0 --benchmark${NC}"