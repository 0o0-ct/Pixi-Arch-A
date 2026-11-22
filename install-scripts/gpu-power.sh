#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Ahorro de energía declarativo para GPU/CPU.
# Se ejecuta durante install.sh (con sudo activo) y también en copy.sh al
# actualizar dotfiles ya instalados. No crea ningún servicio ni daemon.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.." || exit 1

if ! source "$SCRIPT_DIR/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_gpu-power.log"

printf "%s Configurando ahorro de energía (GPU/CPU)...\n" "${INFO}"

# ---------------------------------------------------------------------------
# 1) NVIDIA: Dynamic Power Management adaptativo.
#    Sustituye el valor peligroso PowerMizerDefault=0x2 (rendimiento máximo)
#    y EnableGpuFirmware=1 por una configuración mínima y estable.
#    Requiere sudo; si no hay credenciales activas se omite con aviso.
# ---------------------------------------------------------------------------
if lspci -nn 2>/dev/null | grep -qi "nvidia"; then
  MODPROBE="/etc/modprobe.d/nvidia-power.conf"

  if sudo -n true 2>/dev/null; then
    if [ -f "$MODPROBE" ]; then
      BACKUP="${MODPROBE}.bak.$(date +%s)"
      if sudo cp -f "$MODPROBE" "$BACKUP" >>"$LOG" 2>&1; then
        printf "%s Respaldo previo guardado en %s\n" "${NOTE}" "$BACKUP"
      fi
    fi

    if sudo tee "$MODPROBE" >/dev/null 2>>"$LOG" <<'EOF'
# NVIDIA: ahorro dinámico y suspensión en reposo (sin scripts).
# Generado por el instalador de Pixi-Arch-A. NO fuerza rendimiento máximo.
options nvidia NVreg_DynamicPowerManagement=1
options nvidia NVreg_DynamicPowerManagementVideoMemoryThreshold=100
EOF
    then
      printf "%s %s instalado (se aplica tras reiniciar).\n" "${OK}" "$MODPROBE"
    else
      printf "%s No se pudo escribir %s (revisa %s).\n" "${WARN}" "$MODPROBE" "$LOG"
    fi
  else
    printf "%s Sin sudo activo: se omite %s. Vuelve a ejecutar install.sh para aplicarlo.\n" "${NOTE}" "$MODPROBE"
  fi
else
  printf "%s NVIDIA no detectada: se omite configuración de modprobe.\n" "${NOTE}"
fi

# ---------------------------------------------------------------------------
# 2) Perfil de energía power-saver (power-profiles-daemon).
#    No es un script: es el estado declarativo del servicio del sistema.
# ---------------------------------------------------------------------------
if command -v powerprofilesctl >/dev/null 2>&1; then
  if ! pgrep -x power-profiles-daemon >/dev/null 2>&1; then
    sudo -n systemctl enable --now power-profiles-daemon.service >>"$LOG" 2>&1 || true
  fi

  if powerprofilesctl set power-saver >>"$LOG" 2>&1; then
    printf "%s Perfil power-saver activado.\n" "${OK}"
  else
    printf "%s No se pudo activar power-saver (revisa %s).\n" "${WARN}" "$LOG"
  fi
else
  printf "%s powerprofilesctl no disponible: se omite el perfil.\n" "${NOTE}"
fi

printf "%s Ahorro de energía configurado.\n" "${OK}"
