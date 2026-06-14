#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Detecta el hardware de GPU del sistema y genera dinámicamente las variables de entorno adecuadas.

set -euo pipefail

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

# Archivos de salida
HYPR_GPU_CONF="$HOME/.config/hypr/configs/ENVariables_GPU.conf"
UWSM_ENV_DIR="$HOME/.config/uwsm"
UWSM_ENV_FILE="$UWSM_ENV_DIR/env"

# Asegurar que existan los directorios
mkdir -p "$(dirname "$HYPR_GPU_CONF")"
mkdir -p "$UWSM_ENV_DIR"

# Limpiar archivos anteriores si existen
echo "# Variables de entorno de GPU generadas automáticamente" > "$HYPR_GPU_CONF"
# Si existe uwsm env, limpiamos las líneas viejas de GPU
if [ -f "$UWSM_ENV_FILE" ]; then
    sed -i '/# GPU_DETECT_START/,/# GPU_DETECT_END/d' "$UWSM_ENV_FILE"
fi

# Iniciar bloque UWSM
uwsm_content="# GPU_DETECT_START\n"
hypr_content="# Configuración de GPU dinámica para Hyprland\n"

if [ -n "$nvidia_card" ] && [ -n "$intel_card" ]; then
    # LAPTOP HÍBRIDO (Intel + NVIDIA)
    hypr_content+="env = WLR_DRM_DEVICES,$intel_card:$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,iHD\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export WLR_DRM_DEVICES=$intel_card:$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=iHD\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"
    echo "[GPU] Sistema híbrido (Intel + NVIDIA) configurado."

elif [ -n "$nvidia_card" ] && [ -n "$amd_card" ]; then
    # LAPTOP HÍBRIDO (AMD + NVIDIA)
    hypr_content+="env = WLR_DRM_DEVICES,$amd_card:$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,radeonsi\n"
    hypr_content+="env = VDPAU_DRIVER,radeonsi\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export WLR_DRM_DEVICES=$amd_card:$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=radeonsi\n"
    uwsm_content+="export VDPAU_DRIVER=radeonsi\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"
    echo "[GPU] Sistema híbrido (AMD + NVIDIA) configurado."

elif [ -n "$nvidia_card" ]; then
    # DEDICADA NVIDIA SOLAMENTE
    hypr_content+="env = WLR_DRM_DEVICES,$nvidia_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,nvidia\n"
    hypr_content+="env = GBM_BACKEND,nvidia-drm\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,nvidia\n"

    uwsm_content+="export WLR_DRM_DEVICES=$nvidia_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=nvidia\n"
    uwsm_content+="export GBM_BACKEND=nvidia-drm\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=nvidia\n"
    echo "[GPU] Tarjeta Nvidia dedicada configurada."

elif [ -n "$amd_card" ]; then
    # INTEGRADA/DEDICADA AMD SOLAMENTE
    hypr_content+="env = WLR_DRM_DEVICES,$amd_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,radeonsi\n"
    hypr_content+="env = VDPAU_DRIVER,radeonsi\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export WLR_DRM_DEVICES=$amd_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=radeonsi\n"
    uwsm_content+="export VDPAU_DRIVER=radeonsi\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"
    echo "[GPU] Tarjeta AMD configurada."

elif [ -n "$intel_card" ]; then
    # INTEGRADA INTEL SOLAMENTE
    hypr_content+="env = WLR_DRM_DEVICES,$intel_card\n"
    hypr_content+="env = LIBVA_DRIVER_NAME,iHD\n"
    hypr_content+="env = __GLX_VENDOR_LIBRARY_NAME,mesa\n"

    uwsm_content+="export WLR_DRM_DEVICES=$intel_card\n"
    uwsm_content+="export LIBVA_DRIVER_NAME=iHD\n"
    uwsm_content+="export __GLX_VENDOR_LIBRARY_NAME=mesa\n"
    echo "[GPU] Tarjeta Intel integrada configurada."
else
    echo "[GPU] No se detectó ninguna GPU estándar compatible. Omitiendo cambios."
fi

uwsm_content+="# GPU_DETECT_END"

# Escribir configuraciones
printf "%b" "$hypr_content" >> "$HYPR_GPU_CONF"
printf "%b\n" "$uwsm_content" >> "$UWSM_ENV_FILE"
