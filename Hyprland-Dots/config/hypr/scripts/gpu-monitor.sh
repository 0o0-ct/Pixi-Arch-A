#!/usr/bin/env bash
# /* ---- 🔍 gpu-monitor.sh — Monitor dinámico de GPU en tiempo real 💫 ---- */
# Monitorea el uso de GPU NVIDIA y gestiona dinámicamente el offload.
# Funciones:
#   1. Detecta cuando la GPU está ociosa y la apaga para ahorrar energía
#   2. Detecta cuando una app desconocida empieza a usar GPU y la activa
#   3. Reporta temperatura y uso en tiempo real
#   4. Ajusta según si hay monitor externo conectado
#
# Se ejecuta como servicio systemd o en segundo plano

set -euo pipefail

# ============================================================
# CONFIGURACIÓN
# ============================================================
CHECK_INTERVAL=15        # segundos entre verificaciones
GPU_IDLE_THRESHOLD=5     # % uso máximo para considerar GPU ociosa
GPU_BUSY_THRESHOLD=30    # % uso mínimo para considerar GPU ocupada
TEMP_WARNING=75          # °C para advertencia de temperatura
TEMP_CRITICAL=85         # °C para acción crítica
IDLE_TIMEOUT=120         # segundos sin uso antes de intentar apagar GPU
LOG_FILE="$HOME/.cache/gpu-monitor.log"
STATE_FILE="$HOME/.cache/gpu-monitor.state"
NOTIFY_CMD=""            # comando para notificaciones (opcional)

# Detectar sistema de notificación
if command -v notify-send >/dev/null 2>&1; then
    NOTIFY_CMD="notify-send"
elif command -v swaync-client >/dev/null 2>&1; then
    NOTIFY_CMD="swaync-client -t"
fi

# ============================================================
# FUNCIONES
# ============================================================

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if [ -n "$NOTIFY_CMD" ]; then
        if [ "$NOTIFY_CMD" = "swaync-client" ]; then
            swaync-client -t "$message" -a "$title" 2>/dev/null || true
        else
            notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true
        fi
    fi
    log_msg "NOTIFICACIÓN: $title - $message"
}

# Obtener uso actual de GPU NVIDIA
get_nvidia_usage() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' || echo "0"
    else
        echo "0"
    fi
}

# Obtener uso de memoria GPU
get_nvidia_mem_usage() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=utilization.memory --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' || echo "0"
    else
        echo "0"
    fi
}

# Obtener temperatura GPU NVIDIA
get_nvidia_temp() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' || echo "0"
    else
        echo "0"
    fi
}

# Obtener consumo de energía GPU
get_nvidia_power() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=power.draw --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' | awk '{print int($1)}' || echo "0"
    else
        echo "0"
    fi
}

# Obtener reloj GPU
get_nvidia_clock() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=clocks.graphics --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' | awk '{print int($1)}' || echo "0"
    else
        echo "0"
    fi
}

# Obtener VRAM usada
get_nvidia_vram() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' | awk '{print int($1)}' || echo "0"
    else
        echo "0"
    fi
}

# Detectar si hay monitor externo conectado
has_external_monitor() {
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
    
    return 1
}

# Obtener lista de procesos usando GPU
get_gpu_processes() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi pmon -c 1 2>/dev/null | tail -n +4 | grep -v "^$" || true
    fi
}

# Guardar estado
save_state() {
    local state="$1"
    local timestamp
    timestamp=$(date +%s)
    echo "$state:$timestamp" > "$STATE_FILE" 2>/dev/null || true
}

# Leer estado
read_state() {
    if [ -f "$STATE_FILE" ]; then
        cut -d: -f1 "$STATE_FILE" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Leer timestamp del estado
read_state_time() {
    if [ -f "$STATE_FILE" ]; then
        cut -d: -f2 "$STATE_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Intentar reducir el rendimiento de GPU (power saving)
set_gpu_power_save() {
    # NVIDIA en Linux no permite apagar completamente la dGPU fácilmente
    # pero podemos forzar el nivel de rendimiento más bajo
    if command -v nvidia-smi >/dev/null 2>&1; then
        # Forzar el nivel de rendimiento más bajo (P8/P13).
        # Ajustar relojes exige privilegios de root: si el usuario no los tiene
        # se omite el ajuste en lugar de repetir el error en cada ciclo.
        if nvidia-smi -lgc 210,405 >/dev/null 2>&1; then
            nvidia-smi -pm 1 >/dev/null 2>&1 || true  # persistant mode para transiciones rápidas
            log_msg "GPU Power Save: reloj forzado a mínimo (210/405 MHz)"
        else
            log_msg "GPU Power Save: sin permiso para ajustar relojes (requiere root); se omite el ajuste."
        fi
    fi
}

# Restaurar rendimiento normal de GPU
set_gpu_performance() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        # -auto-boost no existe en los nvidia-smi actuales; -rgc libera el
        # bloqueo de reloj aplicado por set_gpu_power_save
        if nvidia-smi -rgc >/dev/null 2>&1; then
            log_msg "GPU Performance: bloqueo de reloj liberado"
        else
            log_msg "GPU Performance: sin permiso para liberar el bloqueo de reloj (requiere root)."
        fi
    fi
}

# ============================================================
# MONITOR PRINCIPAL
# ============================================================

log_msg "════════════════════════════════════════════════════"
log_msg "GPU Monitor iniciado"
log_msg "Intervalo: ${CHECK_INTERVAL}s | Idle: ${GPU_IDLE_THRESHOLD}% | Busy: ${GPU_BUSY_THRESHOLD}%"
log_msg "════════════════════════════════════════════════════"

# Estado inicial
PREV_STATE="unknown"
IDLE_COUNT=0
NOTIFY_COOLDOWN=0  # cooldown para no spamear notificaciones

while true; do
    # Obtener métricas
    GPU_USAGE=$(get_nvidia_usage)
    GPU_TEMP=$(get_nvidia_temp)
    GPU_POWER=$(get_nvidia_power)
    GPU_CLOCK=$(get_nvidia_clock)
    GPU_VRAM=$(get_nvidia_vram)
    GPU_MEM_USAGE=$(get_nvidia_mem_usage)
    
    # Remover % si existe
    GPU_USAGE=${GPU_USAGE%\%}
    GPU_TEMP=${GPU_TEMP%\%}
    GPU_MEM_USAGE=${GPU_MEM_USAGE%\%}
    
    # Estado actual
    CURRENT_STATE="idle"
    
    # Determinar estado
    if [ "$GPU_USAGE" -ge "$GPU_BUSY_THRESHOLD" ] 2>/dev/null; then
        CURRENT_STATE="busy"
    elif [ "$GPU_USAGE" -ge "$GPU_IDLE_THRESHOLD" ] 2>/dev/null; then
        CURRENT_STATE="moderate"
    fi
    
    # Verificar procesos activos
    PROCESSES=$(get_gpu_processes)
    HAS_PROCESSES=0
    if [ -n "$PROCESSES" ]; then
        HAS_PROCESSES=1
    fi
    
    # Monitor externo
    HAS_EXTERNAL=0
    if has_external_monitor; then
        HAS_EXTERNAL=1
    fi
    
    # ============================================================
    # LÓGICA DE GESTIÓN
    # ============================================================
    
    NOW=$(date +%s)
    PREV_TIME=$(read_state_time)
    ELAPSED=$((NOW - PREV_TIME))
    
    # Reducir cooldown de notificaciones
    if [ "$NOTIFY_COOLDOWN" -gt 0 ]; then
        NOTIFY_COOLDOWN=$((NOTIFY_COOLDOWN - CHECK_INTERVAL))
    fi
    
    case "$CURRENT_STATE" in
        idle)
            if [ "$HAS_PROCESSES" -eq 0 ]; then
                IDLE_COUNT=$((IDLE_COUNT + 1))
                
                # Si ha estado idle por mucho tiempo, forzar power save
                if [ "$IDLE_COUNT" -ge $((IDLE_TIMEOUT / CHECK_INTERVAL)) ]; then
                    set_gpu_power_save
                    save_state "idle"
                    
                    if [ "$NOTIFY_COOLDOWN" -le 0 ]; then
                        send_notification "🔋 GPU Ahorro" "La GPU NVIDIA está en modo ahorro de energía."
                        NOTIFY_COOLDOWN=300  # 5 minutos
                    fi
                fi
            else
                # Hay procesos pero uso bajo -> moderate
                CURRENT_STATE="moderate"
                IDLE_COUNT=0
            fi
            ;;
        
        moderate)
            IDLE_COUNT=0
            save_state "moderate"
            
            # Si viene de busy, la carga bajó
            if [ "$PREV_STATE" = "busy" ] && [ "$NOTIFY_COOLDOWN" -le 0 ]; then
                send_notification "📉 GPU Carga Baja" "Uso GPU: ${GPU_USAGE}% | Temp: ${GPU_TEMP}°C"
                NOTIFY_COOLDOWN=300
            fi
            ;;
        
        busy)
            IDLE_COUNT=0
            save_state "busy"
            
            # Restaurar rendimiento si estaba en power save
            set_gpu_performance
            
            # Notificar si es un cambio reciente
            if [ "$PREV_STATE" != "busy" ] && [ "$NOTIFY_COOLDOWN" -le 0 ]; then
                # Obtener nombre del proceso principal
                MAIN_PROCESS=$(echo "$PROCESSES" | head -1 | awk '{print $5}' || echo "desconocido")
                send_notification "🎮 GPU Activa" "Uso: ${GPU_USAGE}% | Proceso: ${MAIN_PROCESS}"
                NOTIFY_COOLDOWN=300
            fi
            ;;
    esac
    
    # ============================================================
    # ALERTAS DE TEMPERATURA
    # ============================================================
    
    if [ "$GPU_TEMP" -ge "$TEMP_CRITICAL" ] 2>/dev/null; then
        if [ "$NOTIFY_COOLDOWN" -le 0 ]; then
            send_notification "🔥 GPU CRÍTICA" "¡Temperatura: ${GPU_TEMP}°C! Cierra aplicaciones pesadas." "critical"
            NOTIFY_COOLDOWN=600  # 10 minutos
            log_msg "ALERTA CRÍTICA: Temperatura ${GPU_TEMP}°C"
            
            # Intentar reducir rendimiento
            set_gpu_power_save
        fi
    elif [ "$GPU_TEMP" -ge "$TEMP_WARNING" ] 2>/dev/null; then
        if [ "$NOTIFY_COOLDOWN" -le 0 ]; then
            send_notification "⚠️  GPU Caliente" "Temperatura: ${GPU_TEMP}°C" "normal"
            NOTIFY_COOLDOWN=300
            log_msg "ADVERTENCIA: Temperatura ${GPU_TEMP}°C"
        fi
    fi
    
    # ============================================================
    # LOG PERIÓDICO (cada 60 segundos)
    # ============================================================
    
    if [ $((NOW % 60)) -lt "$CHECK_INTERVAL" ]; then
        log_msg "Estado: $CURRENT_STATE | Uso: ${GPU_USAGE}% | Temp: ${GPU_TEMP}°C | Power: ${GPU_POWER}W | VRAM: ${GPU_VRAM}MB | Procs: $HAS_PROCESSES | ExtMon: $HAS_EXTERNAL"
    fi
    
    # Actualizar estado previo
    PREV_STATE="$CURRENT_STATE"
    save_state "$CURRENT_STATE"
    
    # Esperar hasta la próxima verificación
    sleep "$CHECK_INTERVAL"
done
