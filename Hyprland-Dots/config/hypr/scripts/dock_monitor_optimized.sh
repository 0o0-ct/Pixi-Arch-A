#!/usr/bin/env bash
# Consolidated dock monitor - uses Hyprland hooks instead of polling

set -uo pipefail

# Verificar que estamos en Hyprland
[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1
[[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Configuración
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
[[ -S "$SOCKET" ]] || exit 1

# Funciones
show_dock() { pkill -f -SIGRTMIN+2 nwg-dock-hyprland 2>/dev/null || true; }
hide_dock() { pkill -f -SIGRTMIN+3 nwg-dock-hyprland 2>/dev/null || true; }
cursor_in_zone() {
    local cursor_y mon_h threshold
    cursor_y="$(hyprctl cursorpos 2>/dev/null | awk -F/ '{print $2}')" || return 1
    mon_h="$(hyprctl monitors 2>/dev/null | grep -E -o '[0-9]+x[0-9]+' | head -1 | awk -Fx '{print $2}')"
    [[ -n "$cursor_y" && -n "$mon_h" && "$mon_h" -gt 0 ]] && threshold=$(( mon_h - 40 )) && [[ "$cursor_y" -ge "$threshold" ]]
}

# Función para manejar eventos de Hyprland
handle_event() {
    local event="$1" data="$2"
    
    case "$event" in
        fullscreen)
            local fs="${data%%,*}"
            if [[ "$fs" == "1" || "$fs" == "2" ]]; then
                # Entra a fullscreen
                if [[ "$prev_fullscreen" -eq 0 ]]; then
                    cancel_hide_timer
                    show_dock
                    prev_fullscreen=1
                fi
            else
                # Sale de fullscreen
                if [[ "$prev_fullscreen" -eq 1 ]]; then
                    cancel_hide_timer
                    show_dock
                    prev_fullscreen=0
                fi
            fi
            ;;
    esac
}

# Estado
prev_fullscreen=0
hide_timer_pid=""

# Funciones de temporizador
cancel_hide_timer() {
    if [[ -n "$hide_timer_pid" ]] && kill -0 "$hide_timer_pid" 2>/dev/null; then
        kill "$hide_timer_pid" 2>/dev/null || true
        wait "$hide_timer_pid" 2>/dev/null || true
    fi
    hide_timer_pid=""
}

schedule_hide() {
    cancel_hide_timer
    (
        sleep 2
        if is_fullscreen && ! cursor_in_zone; then
            hide_dock
        fi
    ) &
    hide_timer_pid=$!
}

is_fullscreen() {
    hyprctl activewindow 2>/dev/null | grep -E -o 'fullscreen:[[:space:]]*[0-9]+' | grep -E -o '[0-9]+$' | grep -q '1\|2'
}

# Conectar al socket y escuchar eventos
socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r line; do
    # Los eventos tienen formato: EVENT>>DATA
    case "$line" in
        EVENT\>\>* )
            rest="${line#EVENT>>}"
            event="${rest%%>>*}"
            data="${rest#*>}"
            handle_event "$event" "$data"
            ;;
    esac
done &