#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# toggle_fullscreen.sh — Alterna entre pantalla completa y ventana flotante (redimensionable)
#
# Usa el socket de Hyprland directamente (socat) para enviar comandos de fullscreen.
# Comportamiento:
#   - Si la ventana activa está en pantalla completa → la restaura a ventana flotante redimensionable
#   - Si la ventana activa está en modo ventana → la pone en pantalla completa

set -uo pipefail

[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1
[[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if [[ ! -S "$SOCKET" ]]; then
    echo "[toggle_fullscreen] Error: socket no encontrado en $SOCKET" >&2
    exit 1
fi

# Obtener el estado de fullscreen de la ventana activa (1=sí, 2=fake fullscreen, 0=no)
FS_STATE="$(hyprctl activewindow 2>/dev/null | grep -E -o 'fullscreen:[[:space:]]*[0-9]+' | grep -E -o '[0-9]+$')"

if [[ "$FS_STATE" == "1" || "$FS_STATE" == "2" ]]; then
    # Está en fullscreen → quitar fullscreen y poner como ventana flotante
    echo "fullscreen>>0" | socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
    sleep 0.1
    echo "float" | socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
else
    # Está en ventana → poner en pantalla completa
    echo "fullscreen>>1" | socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
fi
