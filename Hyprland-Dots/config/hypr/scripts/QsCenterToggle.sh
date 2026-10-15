#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# QsCenterToggle.sh <netcenter|btcenter|audiocenter>
#
# Abre/cierra un panel "center" de quickshell (netcenter WiFi, btcenter
# Bluetooth, audiocenter dispositivos de audio). Lo llama waybar desde los
# módulos network / bluetooth / pulseaudio. Si el panel todavía no está
# corriendo (p. ej. el servicio systemd está detenido) lo arranca primero y
# reintenta el toggle hasta que el IPC responde.
set -u

config="${1:-}"
if [ -z "$config" ]; then
    echo "Uso: $0 <netcenter|btcenter|audiocenter>" >&2
    exit 2
fi

if ! pgrep -f "qs -c $config" >/dev/null 2>&1; then
    setsid qs -c "$config" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
        qs -c "$config" ipc call panel toggle >/dev/null 2>&1 && exit 0
        sleep 0.05
    done
    exit 1
fi

qs -c "$config" ipc call panel toggle >/dev/null 2>&1
