#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Overview toggle wrapper:
#   - Si la instancia de Quickshell "overview" no existe, la arranca.
#   - Si ya existe, alterna el overlay por IPC (sin duplicar procesos).
#   - Fallback a AGS solo si Quickshell no está disponible.

set -uo pipefail

overview_running() {
    qs list --all 2>/dev/null | grep -qF "/quickshell/overview/shell.qml"
}

overview_toggle() {
    qs -c overview ipc call overview toggle >/dev/null 2>&1
}

# 1) Quickshell: alternar si ya está corriendo
if command -v qs >/dev/null 2>&1; then
    if overview_running; then
        if overview_toggle; then
            exit 0
        fi
    fi

    # 2) No está corriendo: arrancar daemonizado y abrir
    qs -c overview -d >/dev/null 2>&1 &
    for _ in $(seq 1 30); do
        sleep 0.05
        if overview_running && overview_toggle; then
            exit 0
        fi
    done
fi

# 3) Fallback AGS (solo si está instalado)
if command -v ags >/dev/null 2>&1; then
    pkill rofi >/dev/null 2>&1 || true
    if ags -t 'overview' >/dev/null 2>&1; then
        exit 0
    fi
    ags >/dev/null 2>&1 &
    sleep 0.6
    if ags -t 'overview' >/dev/null 2>&1; then
        exit 0
    fi
fi

notify-send "Overview" "No se pudo abrir Quickshell overview" -u low 2>/dev/null || true
exit 1
