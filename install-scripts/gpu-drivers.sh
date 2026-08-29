#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# GPU Driver Auto-Detection & Installation
# Detecta TODAS las GPUs del sistema e instala los drivers correctos

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_gpu-drivers.log"

echo "${INFO} Detectando GPUs del sistema..."
printf "\n%.0s" {1..1}

has_intel=false
has_amd=false
has_nvidia=false

while read -r gpu_vendor; do
  case "$gpu_vendor" in
    intel) has_intel=true ;;
    amd) has_amd=true ;;
    nvidia) has_nvidia=true ;;
  esac
done < <(for card in /sys/class/drm/card[0-9]; do
  [ -f "$card/device/vendor" ] || continue
  vendor=$(cat "$card/device/vendor")
  case "$vendor" in
    0x8086) echo "intel" ;;
    0x10de) echo "nvidia" ;;
    0x1002) echo "amd" ;;
  esac
done)

# fallback si /sys/class/drm no dio resultados
if [ "$has_intel" != true ] && [ "$has_amd" != true ] && [ "$has_nvidia" != true ]; then
  while read -r line; do
    if echo "$line" | grep -qi "intel"; then has_intel=true; fi
    if echo "$line" | grep -qi "nvidia"; then has_nvidia=true; fi
    if echo "$line" | grep -qiE "amd|radeon"; then has_amd=true; fi
  done < <(lspci -nn | grep -iE "VGA|3D")
fi

# Detectar si es laptop (batería presente)
is_laptop=false
[ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ] && is_laptop=true

# === INTEL ===
if [ "$has_intel" = true ]; then
  echo "${INFO} GPU Intel detectada"
  printf "\n%s - ${SKY_BLUE}Instalando drivers Intel${RESET} ....\n" "${NOTE}"
  intel_pkgs=(
    vulkan-intel
    intel-media-driver
    libva-intel-driver
  )
  for pkg in "${intel_pkgs[@]}"; do
    install_package "$pkg" "$LOG"
  done
  echo "${OK} Drivers Intel instalados correctamente."
fi

# === AMD ===
if [ "$has_amd" = true ]; then
  echo "${INFO} GPU AMD/ATI detectada"
  printf "\n%s - ${SKY_BLUE}Instalando drivers AMD${RESET} ....\n" "${NOTE}"
  amd_pkgs=(
    vulkan-radeon
    libva-mesa-driver
    mesa-vdpau
  )
  for pkg in "${amd_pkgs[@]}"; do
    install_package "$pkg" "$LOG"
  done
  echo "${OK} Drivers AMD instalados correctamente."
fi

# === NVIDIA ===
if [ "$has_nvidia" = true ]; then
  echo "${INFO} GPU NVIDIA detectada"
  printf "\n%s - ${SKY_BLUE}Configurando GPU NVIDIA${RESET} ....\n" "${NOTE}"
  "$SCRIPT_DIR/nvidia.sh" 2>&1 | tee -a "$LOG"
  "$SCRIPT_DIR/nvidia_nouveau.sh" 2>&1 | tee -a "$LOG"

  if [ "$is_laptop" = true ] && { [ "$has_intel" = true ] || [ "$has_amd" = true ]; }; then
    echo "${INFO} Laptop híbrida detectada. Instalando nvidia-prime..."
    install_package "nvidia-prime" "$LOG"
  fi
fi

# === Sin GPUs conocidas ===
if [ "$has_intel" != true ] && [ "$has_amd" != true ] && [ "$has_nvidia" != true ]; then
  echo "${INFO} No se detectaron GPUs conocidas. Omitiendo instalación de drivers."
fi

printf "\n%.0s" {1..2}
echo "${OK} ${SKY_BLUE}Configuración de GPU completada.${RESET}"
printf "\n%.0s" {1..1}
