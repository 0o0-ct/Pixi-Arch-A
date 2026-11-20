#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Optimización ligera al inicio de sesión - sin interacción usuario
# Se ejecuta desde StartupApps.sh o hypridle

set -euo pipefail

LOG_DIR="$HOME/.cache/pixi-arch"
LOG_FILE="$LOG_DIR/startup-optimize.log"
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
success() { log "SUCCESS" "$@"; }

info "=== Iniciando optimización de inicio ==="

# 1. Limpiar cache wallust si > 500MB
WALLUST_CACHE="$HOME/.cache/wallust"
if [ -d "$WALLUST_CACHE" ]; then
    CACHE_SIZE_KB=$(du -sk "$WALLUST_CACHE" 2>/dev/null | cut -f1 || echo 0)
    if [ "$CACHE_SIZE_KB" -gt 512000 ]; then
        warn "Cache wallust > 500MB ($CACHE_SIZE_KB KB). Limpiando..."
        rm -rf "$WALLUST_CACHE"/*
        success "Cache wallust limpiado"
    fi
fi

# 2. Limpiar cache paru/yay de builds antiguos (> 7 días)
for cache_dir in "$HOME/.cache/paru/clone" "$HOME/.cache/yay"; do
    if [ -d "$cache_dir" ]; then
        find "$cache_dir" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
        info "Limpieza de builds antiguos en $(basename "$cache_dir")"
    fi
done

# 3. Aplicar swappiness optimizado si no está aplicado
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 60)
if [ "$CURRENT_SWAPPINESS" -gt 10 ]; then
    # Solo aplicar si tenemos sudo sin password o ya está configurado persistente
    if sudo -n true 2>/dev/null; then
        sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 && \
            success "Swappiness aplicado (10)" || \
            warn "No se pudo aplicar swappiness"
    elif ! grep -q "vm.swappiness=10" /etc/sysctl.d/99-swappiness.conf 2>/dev/null; then
        info "Swappiness no optimizado (actual: $CURRENT_SWAPPINESS). Ejecuta system-optimize.sh con sudo para arreglar."
    fi
fi

# 4. VFS cache pressure
CURRENT_VCP=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo 100)
if [ "$CURRENT_VCP" -gt 50 ] && sudo -n true 2>/dev/null; then
    sudo sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1 && \
        success "VFS cache pressure optimizado (50)" || true
fi

# 5. Verificar PerformanceProfile.conf existe
PERF_PROFILE_FILE="$HOME/.config/hypr/UserConfigs/PerformanceProfile.conf"
if [ ! -f "$PERF_PROFILE_FILE" ]; then
    warn "PerformanceProfile.conf no existe, creando perfil balanced por defecto..."
    mkdir -p "$(dirname "$PERF_PROFILE_FILE")"
    cat > "$PERF_PROFILE_FILE" << 'EOF'
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Performance Profile — Controla blur, sombras, animaciones y apps de inicio
# PERFIL: balanced (por defecto - equilibrio visual/rendimiento)

$PERF_PROFILE = balanced

# Blur: MODERADO (optimizado)
$BLUR_ENABLED = 1
$BLUR_SIZE = 5
$BLUR_PASSES = 1
$BLUR_VIBRANCY = 0.0
$BLUR_CONTRAST = 0.85
$BLUR_BRIGHTNESS = 0.90

# Shadows: MODERADAS
$SHADOW_ENABLED = 1
$SHADOW_RANGE = 6
$SHADOW_RENDER_POWER = 1

# Animations: ESTÁNDAR (ventanas desactivadas para rendimiento)
$ANIM_BORDER_ENABLED = 1
$ANIM_WINDOW_ENABLED = 0
$ANIM_SPEED_FACTOR = 1.0
$BASE_WIN_SPEED = 5
$BASE_WIN_IN_SPEED = 4
$BASE_WIN_OUT_SPEED = 3
$BASE_WIN_MOVE_SPEED = 4
$BASE_BORDER_SPEED = 1
$BASE_FADE_SPEED = 3
$BASE_WS_SPEED = 4

# Startup Apps: TODAS
$START_AGS = 1
$START_OVERVIEW = 1
EOF
    success "PerformanceProfile.conf creado"
fi

# 6. GPU monitor service para laptops híbridas
GPU_TYPE_FILE="$HOME/.config/hypr/configs/.gpu_type"
if [ -f "$GPU_TYPE_FILE" ]; then
    GPU_TYPE=$(cat "$GPU_TYPE_FILE")
    if [[ "$GPU_TYPE" == "hybrid_intel_nvidia" || "$GPU_TYPE" == "hybrid_amd_nvidia" ]]; then
        GPU_MONITOR_SERVICE="$HOME/.config/systemd/user/gpu-monitor.service"
        if [ ! -f "$GPU_MONITOR_SERVICE" ] && [ -f "$HOME/.config/hypr/scripts/gpu-monitor.service" ]; then
            mkdir -p "$HOME/.config/systemd/user"
            cp "$HOME/.config/hypr/scripts/gpu-monitor.service" "$GPU_MONITOR_SERVICE"
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable gpu-monitor.service 2>/dev/null || true
            if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                systemctl --user start gpu-monitor.service 2>/dev/null || true
            fi
            info "gpu-monitor.service configurado para laptop híbrida"
        fi
    fi
fi

success "=== Optimización de inicio completada ==="
exit 0