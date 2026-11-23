#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# QsCenterToggle.sh <netcenter|btcenter|audiocenter>
# Alterna los paneles de red/Bluetooth y abre el mezclador GTK glass-audio.
set -u

config="${1:-}"
if [ -z "$config" ]; then
    echo "Uso: $0 <netcenter|btcenter|audiocenter>" >&2
    exit 2
fi

case "$config" in
    netcenter)
        pidof glass-net >/dev/null 2>&1 || { setsid glass-net --hidden >/dev/null 2>&1 & sleep 0.3; }
        kill -USR1 "$(pidof glass-net)" 2>/dev/null || true
        exit 0
        ;;
    btcenter)
        pidof glass-bt >/dev/null 2>&1 || { setsid glass-bt --hidden >/dev/null 2>&1 & sleep 0.3; }
        kill -USR1 "$(pidof glass-bt)" 2>/dev/null || true
        exit 0
        ;;
    audiocenter)
        # Use the per-user installation so clicks never reopen a stale system binary.
        audio_bin="$HOME/.local/bin/glass-audio"
        if [ ! -x "$audio_bin" ]; then
            audio_bin="$(command -v glass-audio || true)"
        fi
        if [ -z "$audio_bin" ] || [ ! -x "$audio_bin" ]; then
            notify-send -u critical "Mezclador de audio" "No se encontró glass-audio. Ejecuta install-scripts/glass-audio.sh." 2>/dev/null || true
            exit 1
        fi
        setsid "$audio_bin" >/dev/null 2>&1 &
        exit 0
        ;;
    *)
        echo "Configuración desconocida: $config" >&2
        exit 2
        ;;
esac
