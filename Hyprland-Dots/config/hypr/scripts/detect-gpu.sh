#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Detecta el hardware de GPU del sistema y genera dinámicamente las variables de entorno adecuadas.
# Versión mejorada: maneja híbridos, VM, power management NVIDIA, y cursores condicionales.

set -euo pipefail

# Detect if the system is a laptop
is_laptop() {
    if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
        return 0
    fi
    if command -v hostnamectl >/dev/null 2>&1; then
        if hostnamectl | grep -q -i 'Chassis: laptop'; then
            return 0
        fi
    fi
    return 1
}

# Detect if running in a VM
is_vm() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        systemd-detect-virt -q && return 0
    fi
    return 1
}

# Get NVIDIA driver version (major number only)
get_nvidia_version() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | cut -d. -f1
    fi
}

# Buscar tarjetas gráficas en el sistema
intel_card=""
nvidia_card=""
amd_card=""

for card in /sys/class/drm/card[0-9]; do
    if [ -f "$card/device/vendor" ]; then
        vendor=$(cat "$card/device/vendor")
        card_name="/dev/dri/$(basename "$card")"
        if [ "$vendor" = "0x8086" ]; then
            intel_card="$card_name"
        elif [ "$vendor" = "0x10de" ]; then
            nvidia_card="$card_name"
        elif [ "$vendor" = "0x1002" ]; then
            amd_card="$card_name"
        fi
    fi
done

# Detecciones de sistema
IS_LAPTOP=0
is_laptop && IS_LAPTOP=1

IS_VM=0
is_vm && IS_VM=1

NVIDIA_VERSION=$(get_nvidia_version)

# Archivos de salida
HYPR_GPU_CONF="$HOME/.config/hypr/configs/ENVariables_GPU.conf"
HYPR_GPU_CONF_HL="$HOME/.config/hypr/configs/ENVariables_GPU.hl"
UWSM_ENV_DIR="$HOME/.config/uwsm"
UWSM_ENV_FILE="$UWSM_ENV_DIR/env"
GPU_TYPE_FILE="$HOME/.config/hypr/configs/.gpu_type"

# Variable para almacenar el tipo de GPU detectado
GPU_TYPE="unknown"

# Asegurar que existan los directorios
mkdir -p "$(dirname "$HYPR_GPU_CONF")"
mkdir -p "$UWSM_ENV_DIR"

# Limpiar archivos anteriores si existen
echo "# Variables de entorno de GPU generadas automáticamente por detect-gpu.sh" > "$HYPR_GPU_CONF"
echo "# Variables de entorno de GPU generadas automáticamente por detect-gpu.sh" > "$HYPR_GPU_CONF_HL"
# Si existe uwsm env, limpiamos las líneas viejas de GPU
if [ -f "$UWSM_ENV_FILE" ]; then
    sed -i '/# GPU_DETECT_START/,/# GPU_DETECT_END/d' "$UWSM_ENV_FILE"
fi

# Iniciar bloque UWSM
uwsm_content="# GPU_DETECT_START\n"
hypr_content="# Configuración de GPU dinámica para Hyprland\n"

# ============================================================
# CASO 1: LAPTOP HÍBRIDO Intel + NVIDIA
# ============================================================
if [ -n "$nvidia_card" ] && [ -n "$intel_card" ] && [ "$IS_LAPTOP" -eq 1 ]; then
    # iGPU = display principal, dGPU = offload
    hypr_content+="env = AQ_DRM_DEVICES,$intel_card:$nvidia_card\n"
    hypr_content+="env = WLR_DRM_DEVICES,$intel_card:$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,iHD\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export AQ_DRM_DEVICES=$intel_card:$nvidia_card\n"
    uwsm_content+="export WLR_DRM_DEVICES=$intel_card:$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=iHD\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"

    # NVIDIA optimizations (solo para offload dinámico, NO global)
    # __NV_PRIME_RENDER_OFFLOAD se activa solo por aplicación mediante prime-launch.sh
    hypr_content+="env = __GL_THREADED_OPTIMIZATIONS,1\n"
    hypr_content+="env = __GL_MaxFramesAllowed,1\n"
    # NOTA: __NV_PRIME_RENDER_OFFLOAD NO se establece globalmente para evitar sobrecalentamiento
    # Use prime-launch.sh o __NV_PRIME_RENDER_OFFLOAD=1 para apps que lo requieran

    uwsm_content+="export __GL_THREADED_OPTIMIZATIONS=1\n"
    uwsm_content+="export __GL_MaxFramesAllowed=1\n"
    # NOTA: __NV_PRIME_RENDER_OFFLOAD NO se establece globalmente

    GPU_TYPE="hybrid_intel_nvidia"
    echo "[GPU] Sistema híbrido (Intel + NVIDIA) configurado: iGPU=display, dGPU=offload dinámico."

# ============================================================
# CASO 2: LAPTOP HÍBRIDO AMD + NVIDIA
# ============================================================
elif [ -n "$nvidia_card" ] && [ -n "$amd_card" ] && [ "$IS_LAPTOP" -eq 1 ]; then
    hypr_content+="env = AQ_DRM_DEVICES,$amd_card:$nvidia_card\n"
    hypr_content+="env = WLR_DRM_DEVICES,$amd_card:$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,radeonsi\n"
    hypr_content+="env = VDPAU_DRIVER,radeonsi\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export AQ_DRM_DEVICES=$amd_card:$nvidia_card\n"
    uwsm_content+="export WLR_DRM_DEVICES=$amd_card:$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=radeonsi\n"
    uwsm_content+="export VDPAU_DRIVER=radeonsi\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"

    # NVIDIA optimizations (solo para offload dinámico, NO global)
    # __NV_PRIME_RENDER_OFFLOAD se activa solo por aplicación mediante prime-launch.sh
    hypr_content+="env = __GL_THREADED_OPTIMIZATIONS,1\n"
    hypr_content+="env = __GL_MaxFramesAllowed,1\n"
    # NOTA: __NV_PRIME_RENDER_OFFLOAD NO se establece globalmente para evitar sobrecalentamiento
    # Use prime-launch.sh o __NV_PRIME_RENDER_OFFLOAD=1 para apps que lo requieran

    uwsm_content+="export __GL_THREADED_OPTIMIZATIONS=1\n"
    uwsm_content+="export __GL_MaxFramesAllowed=1\n"
    # NOTA: __NV_PRIME_RENDER_OFFLOAD NO se establece globalmente

    GPU_TYPE="hybrid_amd_nvidia"
    echo "[GPU] Sistema híbrido (AMD + NVIDIA) configurado: iGPU=display, dGPU=offload dinámico."

# ============================================================
# CASO 3: NVIDIA DEDICADA SOLAMENTE (Desktop o laptop sin iGPU)
# ============================================================
elif [ -n "$nvidia_card" ]; then
    hypr_content+="env = AQ_DRM_DEVICES,$nvidia_card\n"
    hypr_content+="env = WLR_DRM_DEVICES,$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,nvidia\n"
    hypr_content+="env = GBM_BACKEND,nvidia-drm\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,nvidia\n"
    hypr_content+="env = __GL_THREADED_OPTIMIZATIONS,1\n"
    hypr_content+="env = __GL_MaxFramesAllowed,1\n"

    uwsm_content+="export AQ_DRM_DEVICES=$nvidia_card\n"
    uwsm_content+="export WLR_DRM_DEVICES=$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=nvidia\n"
    uwsm_content+="export GBM_BACKEND=nvidia-drm\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=nvidia\n"
    uwsm_content+="export __GL_THREADED_OPTIMIZATIONS=1\n"
    uwsm_content+="export __GL_MaxFramesAllowed=1\n"

    GPU_TYPE="nvidia_dedicated"
    echo "[GPU] Tarjeta Nvidia dedicada configurada."

# ============================================================
# CASO 4: AMD SOLAMENTE
# ============================================================
elif [ -n "$amd_card" ]; then
    hypr_content+="env = AQ_DRM_DEVICES,$amd_card\n"
    hypr_content+="env = WLR_DRM_DEVICES,$amd_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,radeonsi\n"
    hypr_content+="env = VDPAU_DRIVER,radeonsi\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export AQ_DRM_DEVICES=$amd_card\n"
    uwsm_content+="export WLR_DRM_DEVICES=$amd_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=radeonsi\n"
    uwsm_content+="export VDPAU_DRIVER=radeonsi\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"

    GPU_TYPE="amd_only"
    echo "[GPU] Tarjeta AMD configurada."

# ============================================================
# CASO 5: INTEL SOLAMENTE
# ============================================================
elif [ -n "$intel_card" ]; then
    hypr_content+="env = AQ_DRM_DEVICES,$intel_card\n"
    hypr_content+="env = WLR_DRM_DEVICES,$intel_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,iHD\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export AQ_DRM_DEVICES=$intel_card\n"
    uwsm_content+="export WLR_DRM_DEVICES=$intel_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=iHD\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"

    GPU_TYPE="intel_only"
    echo "[GPU] Tarjeta Intel integrada configurada."

else
    GPU_TYPE="unknown"
    echo "[GPU] No se detectó ninguna GPU estándar compatible. Omitiendo cambios."
fi

# ============================================================
# AJUSTES PARA MÁQUINA VIRTUAL
# ============================================================
if [ "$IS_VM" -eq 1 ]; then
    hypr_content+="env = WLR_RENDERER_ALLOW_SOFTWARE,1\n"
    hypr_content+="env = WLR_NO_HARDWARE_CURSORS,1\n"
    uwsm_content+="export WLR_RENDERER_ALLOW_SOFTWARE=1\n"
    uwsm_content+="export WLR_NO_HARDWARE_CURSORS=1\n"
    echo "[GPU] VM detectada: WLR_RENDERER_ALLOW_SOFTWARE=1, WLR_NO_HARDWARE_CURSORS=1"
fi

# ============================================================
# AJUSTE DE CURSORES: no_hardware_cursors solo si VM o NVIDIA legacy con glitches
# ============================================================
# En Hyprland, los cursores de hardware son MÁS eficientes.
# Solo desactivarlos (no_hardware_cursors=true) en:
#  - VMs (ya manejado arriba con WLR_NO_HARDWARE_CURSORS)
#  - NVIDIA con driver antiguo (< 550) si hay glitches reportados
# Aquí generamos un snippet de cursor para que SystemSettings.conf pueda hacer source
if [ "$IS_VM" -eq 1 ] || { [ -n "$nvidia_card" ] && [ -n "$NVIDIA_VERSION" ] && [ "$NVIDIA_VERSION" -lt 550 ]; }; then
    hypr_content+="# Cursor fix para VM o NVIDIA legacy\n"
    hypr_content+="cursor {\n  no_hardware_cursors = true\n}\n"
    echo "[GPU] no_hardware_cursors=true activado (VM o NVIDIA driver < 550)."
fi

uwsm_content+="# GPU_DETECT_END"

# Escribir configuraciones
printf "%b" "$hypr_content" >> "$HYPR_GPU_CONF"
printf "%b" "$hypr_content" >> "$HYPR_GPU_CONF_HL"
printf "%b\n" "$uwsm_content" >> "$UWSM_ENV_FILE"

# ============================================================
# ESCRIBIR TIPO DE GPU Y GESTIONAR GPU MONITOR
# ============================================================

# Escribir el tipo de GPU detectado en un archivo para que otros scripts lo usen
echo "$GPU_TYPE" > "$GPU_TYPE_FILE"
echo "[GPU] Tipo de GPU detectado: $GPU_TYPE"

# Gestionar el servicio gpu-monitor automáticamente
# Solo se activa en laptops híbridos con NVIDIA (Intel+NVIDIA o AMD+NVIDIA)
GPU_MONITOR_SERVICE="$HOME/.config/systemd/user/gpu-monitor.service"
GPU_MONITOR_UNIT_FILE="$HOME/.config/hypr/scripts/gpu-monitor.service"

GPU_MONITOR_WANTS_DIR="$HOME/.config/systemd/user/default.target.wants"

case "$GPU_TYPE" in
    hybrid_intel_nvidia|hybrid_amd_nvidia)
        # Laptop híbrido con NVIDIA: activar gpu-monitor
        if [ -f "$GPU_MONITOR_UNIT_FILE" ]; then
            mkdir -p "$HOME/.config/systemd/user"
            cp "$GPU_MONITOR_UNIT_FILE" "$GPU_MONITOR_SERVICE"
            if command -v systemctl >/dev/null 2>&1; then
                systemctl --user daemon-reload 2>/dev/null || true
                # Limpiar el enlace heredado en default.target.wants: arrancaba el
                # servicio ANTES del compositor y activaba graphical-session.target,
                # lo que hacía que uwsm abortara el inicio de Hyprland.
                rm -f "$GPU_MONITOR_WANTS_DIR/gpu-monitor.service"
                # La unidad se ancla en graphical-session.target, de modo que uwsm
                # la levanta junto con el compositor.
                systemctl --user enable gpu-monitor.service 2>/dev/null || true
                # Iniciar solo si ya existe una sesión gráfica en curso
                if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -n "${DISPLAY:-}" ]; then
                    if ! systemctl --user is-active gpu-monitor.service >/dev/null 2>&1; then
                        systemctl --user start gpu-monitor.service 2>/dev/null || true
                    fi
                fi
                echo "[GPU] gpu-monitor.service habilitado (se activa con la sesión gráfica)."
            fi
        else
            echo "[GPU] gpu-monitor.service no encontrado en $GPU_MONITOR_UNIT_FILE"
        fi
        ;;
    nvidia_dedicated)
        # NVIDIA dedicada: no necesita gpu-monitor (la GPU siempre está activa)
        # Desactivar si estaba activo
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user disable --now gpu-monitor.service 2>/dev/null || true
        fi
        rm -f "$GPU_MONITOR_WANTS_DIR/gpu-monitor.service"
        rm -f "$GPU_MONITOR_SERVICE"
        echo "[GPU] gpu-monitor.service desactivado (NVIDIA dedicada, no necesario)."
        ;;
    amd_only|intel_only|unknown)
        # Sin NVIDIA: desactivar gpu-monitor
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user disable --now gpu-monitor.service 2>/dev/null || true
        fi
        rm -f "$GPU_MONITOR_WANTS_DIR/gpu-monitor.service"
        rm -f "$GPU_MONITOR_SERVICE"
        echo "[GPU] gpu-monitor.service desactivado (sin GPU NVIDIA)."
        ;;
esac

# ============================================================
# RESUMEN FINAL
# ============================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           🖥️  GPU Detectada y Configurada                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
case "$GPU_TYPE" in
    hybrid_intel_nvidia)
        echo "  📋 Tipo: Laptop híbrido (Intel + NVIDIA)"
        echo "  🖥️  Display: Intel iGPU (eficiente)"
        echo "  🎮 GPU dedicada: NVIDIA (solo cuando la necesitas)"
        echo "  🔍 Monitor GPU: Activo (ajusta rendimiento automáticamente)"
        echo ""
        echo "  💡 Usa: prime-launch <app> para lanzar apps"
        echo "     prime-launch steam      → NVIDIA automática"
        echo "     prime-launch firefox    → Intel automática"
        echo "     prime-launch --force-nvidia code → Fuerza NVIDIA"
        ;;
    hybrid_amd_nvidia)
        echo "  📋 Tipo: Laptop híbrido (AMD + NVIDIA)"
        echo "  🖥️  Display: AMD iGPU (eficiente)"
        echo "  🎮 GPU dedicada: NVIDIA (solo cuando la necesitas)"
        echo "  🔍 Monitor GPU: Activo (ajusta rendimiento automáticamente)"
        echo ""
        echo "  💡 Usa: prime-launch <app> para lanzar apps"
        echo "     prime-launch steam      → NVIDIA automática"
        echo "     prime-launch firefox    → Intel automática"
        ;;
    nvidia_dedicated)
        echo "  📋 Tipo: NVIDIA dedicada (Desktop o laptop sin iGPU)"
        echo "  🎮 GPU: NVIDIA (siempre activa)"
        echo ""
        echo "  💡 Tu GPU NVIDIA maneja todo. No necesitas prime-launch."
        ;;
    amd_only)
        echo "  📋 Tipo: AMD solamente"
        echo "  🖥️  GPU: AMD (única)"
        echo ""
        echo "  💡 Tu GPU AMD maneja todo. Rendimiento eficiente por defecto."
        ;;
    intel_only)
        echo "  📋 Tipo: Intel integrada solamente"
        echo "  🖥️  GPU: Intel (única)"
        echo ""
        echo "  💡 Tu GPU Intel integrada maneja todo. Máxima eficiencia energética."
        ;;
    *)
        echo "  ⚠️  No se detectó GPU estándar. Usando configuración por defecto."
        ;;
esac

if [ "$IS_VM" -eq 1 ]; then
    echo ""
    echo "  🖥️  Máquina Virtual detectada: renderizado por software activado"
fi

echo ""