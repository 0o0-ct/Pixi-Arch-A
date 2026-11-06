#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# QsCenterToggle.sh <netcenter|btcenter|audiocenter>
#
# Abre/cierra un panel "center" de quickshell (netcenter WiFi, btcenter
# Bluetooth, audiocenter dispositivos de audio). Lo llama waybar desde los
# módulos network / bluetooth / pulseaudio. Si el panel todavía no está
# corriendo lo arranca primero y reintenta el toggle hasta que el IPC responde.
# Dirige el panel al monitor actualmente enfocado.
set -u

config="${1:-}"
if [ -z "$config" ]; then
    echo "Uso: $0 <netcenter|btcenter|audiocenter>" >&2
    exit 2
fi

target_mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)

if ! pgrep -f "qs -c $config" >/dev/null 2>&1; then
    setsid qs -c "$config" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
        if [ -n "$target_mon" ]; then
            qs -c "$config" ipc call panel toggleOn "$target_mon" >/dev/null 2>&1 && exit 0
        fi
        qs -c "$config" ipc call panel toggle >/dev/null 2>&1 && exit 0
        sleep 0.05
    done
    exit 1
fi

if [ -n "$target_mon" ]; then
    qs -c "$config" ipc call panel toggleOn "$target_mon" >/dev/null 2>&1 || qs -c "$config" ipc call panel toggle >/dev/null 2>&1
else
    qs -c "$config" ipc call panel toggle >/dev/null 2>&1
fi
