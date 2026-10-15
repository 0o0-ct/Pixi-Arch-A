#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# netcenter — abre/cierra el panel WiFi independiente (quickshell `netcenter`).
#
# Lo llama waybar (módulo network, click izquierdo). Si el panel todavía no
# está corriendo (p. ej. el servicio systemd está detenido) lo arranca primero
# y espera a que el IPC esté listo.
set -u

if ! pgrep -f "qs -c netcenter" >/dev/null 2>&1; then
    setsid qs -c netcenter >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
        qs -c netcenter ipc call panel toggle >/dev/null 2>&1 && exit 0
        sleep 0.05
    done
    exit 1
fi

qs -c netcenter ipc call panel toggle >/dev/null 2>&1
