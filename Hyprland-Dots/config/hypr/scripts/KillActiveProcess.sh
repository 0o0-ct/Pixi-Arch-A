#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##

# Copied from Discord post. Thanks to @Zorg


# Get id of an active window
active_pid=$(hyprctl activewindow | grep -o 'pid: [0-9]*' | cut -d' ' -f2)

if [[ -z "$active_pid" || ! "$active_pid" =~ ^[0-9]+$ ]]; then
  notify-send -u low -i "$HOME/.config/swaync/images/error.png" "Cerrar Ventana Activa" "No se encontró el PID de la ventana activa."
  exit 1
fi

# Close active window
kill "$active_pid"
