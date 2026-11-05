#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Arranque de daemons de sesión para Hyprland 0.57+.
# Es idempotente: puede ejecutarse en cada login o manualmente sin duplicar procesos.

set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"
scripts_dir="$HOME/.config/hypr/scripts"
wallpaper_file="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

running() {
    pgrep -x "$1" >/dev/null 2>&1
}

# --- Entorno D-Bus / systemd ---------------------------------------------
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP >/dev/null 2>&1 || true
fi
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP >/dev/null 2>&1 || true
fi

# --- Agente Polkit --------------------------------------------------------
if ! pgrep -f '^/usr/lib.*(hyprpolkitagent|polkit.*authentication-agent-1)' >/dev/null 2>&1; then
    if [[ -x "$scripts_dir/Polkit.sh" ]]; then
        nohup "$scripts_dir/Polkit.sh" >/dev/null 2>&1 &
    fi
fi

# --- Portapapeles ---------------------------------------------------------
if command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
    if ! pgrep -f '^wl-paste --type text --watch cliphist store$' >/dev/null 2>&1; then
        nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
    fi
    if ! pgrep -f '^wl-paste --type image --watch cliphist store$' >/dev/null 2>&1; then
        nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
    fi
fi

# --- Fondo de pantalla (swww / awww) -------------------------------------
if ! running swww-daemon && ! running awww-daemon; then
    if command -v swww-daemon >/dev/null 2>&1; then
        nohup swww-daemon >/dev/null 2>&1 &
    elif command -v awww-daemon >/dev/null 2>&1; then
        nohup awww-daemon >/dev/null 2>&1 &
    fi
fi

if command -v swww >/dev/null 2>&1 && [[ -f "$wallpaper_file" ]]; then
    for _ in $(seq 1 20); do
        swww query >/dev/null 2>&1 && break
        sleep 0.1
    done
    swww img "$wallpaper_file" --transition-type none >/dev/null 2>&1 || true
fi

# --- Idle / bloqueo automático -------------------------------------------
if ! running hypridle && command -v hypridle >/dev/null 2>&1; then
    nohup hypridle >/dev/null 2>&1 &
fi

# --- Barra ----------------------------------------------------------------
if ! running waybar && command -v waybar >/dev/null 2>&1; then
    nohup waybar >/dev/null 2>&1 &
fi

# --- Luz nocturna: restaurar estado previo --------------------------------
if [[ -x "$scripts_dir/Hyprsunset.sh" ]]; then
    "$scripts_dir/Hyprsunset.sh" init >/dev/null 2>&1 || true
fi

# --- Indicadores opcionales ----------------------------------------------
if command -v kdeconnect-indicator >/dev/null 2>&1 && ! pgrep -f '^kdeconnect-indicator' >/dev/null 2>&1; then
    nohup kdeconnect-indicator >/dev/null 2>&1 &
fi

exit 0
