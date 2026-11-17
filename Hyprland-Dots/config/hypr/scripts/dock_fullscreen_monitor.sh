#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# dock_fullscreen_monitor.sh — Escucha eventos de fullscreen de Hyprland
# y oculta/muestra automáticamente el dock nwg-dock-hyprland.
#
# Comportamiento:
#   - Al entrar en fullscreen → espera 2 segundos y, si sigue en fullscreen
#     Y el ratón NO está en la zona inferior, oculta el dock.
#   - Al salir de fullscreen → muestra el dock inmediatamente.
#   - Si el ratón está en la zona inferior durante el fullscreen,
#     dock_hover_monitor.sh se encarga de mostrarlo de nuevo.
#
# El dock debe iniciarse en modo resident (-r) para que esto funcione.

# Salir si no estamos en Hyprland
[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1
[[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Verificar que el socket existe
if [[ ! -S "$SOCKET" ]]; then
    echo "[dock-fullscreen-monitor] Error: socket2 no encontrado en $SOCKET" >&2
    exit 1
fi

# --- Configuración ---------------------------------------------------------
HIDE_DELAY=2       # segundos antes de ocultar el dock al entrar en fullscreen
TRIGGER_HEIGHT=40  # píxeles desde el borde inferior que cuentan como "zona del dock"

# --- Estado ----------------------------------------------------------------
prev_fullscreen=0
hide_timer_pid=""   # PID del sleep que programa el ocultado

# --- Funciones -------------------------------------------------------------

show_dock() {
    pkill -f -SIGRTMIN+2 nwg-dock-hyprland 2>/dev/null || true
}

hide_dock() {
    pkill -f -SIGRTMIN+3 nwg-dock-hyprland 2>/dev/null || true
}

# Devuelve la Y del cursor (0 si falla)
get_cursor_y() {
    local pos
    pos="$(hyprctl cursorpos 2>/dev/null)" || return 1
    echo "${pos##*/}" || echo "0"
}

# Devuelve la altura del monitor principal (0 si falla)
get_monitor_height() {
    local line
    line="$(hyprctl monitors 2>/dev/null | grep -E -o '[0-9]+x[0-9]+' | head -1)" || return 1
    echo "${line##*x}" || echo "0"
}

# Devuelve 1 si el ratón está en la zona inferior de activación
cursor_in_zone() {
    local cursor_y mon_h threshold
    cursor_y="$(get_cursor_y)"
    mon_h="$(get_monitor_height)"
    [[ -n "$cursor_y" && -n "$mon_h" && "$mon_h" -gt 0 ]] || return 1
    threshold=$(( mon_h - TRIGGER_HEIGHT ))
    [[ "$cursor_y" -ge "$threshold" ]]
}

# Devuelve 1 si hay una ventana en fullscreen, 0 en caso contrario
is_fullscreen() {
    local fs
    # Intento 1: activewindow
    fs="$(hyprctl activewindow 2>/dev/null | grep -E -o 'fullscreen:[[:space:]]*[0-9]+' | grep -E -o '[0-9]+$')" || echo "0"
    if [[ "$fs" == "1" || "$fs" == "2" ]]; then
        return 0
    fi
    # Intento 2: clients (buscar cualquier ventana con fullscreen)
    if hyprctl clients 2>/dev/null | grep -qE 'fullscreen:[[:space:]]*[12]'; then
        return 0
    fi
    return 1
}

# Cancela cualquier temporizador de ocultado pendiente
cancel_hide_timer() {
    if [[ -n "$hide_timer_pid" ]] && kill -0 "$hide_timer_pid" 2>/dev/null; then
        kill "$hide_timer_pid" 2>/dev/null || true
        wait "$hide_timer_pid" 2>/dev/null || true
    fi
    hide_timer_pid=""
}

# Programa el ocultado tras HIDE_DELAY segundos
schedule_hide() {
    cancel_hide_timer
    (
        sleep "$HIDE_DELAY"
        # Solo ocultar si sigue en fullscreen Y el ratón no está en la zona inferior
        if is_fullscreen && ! cursor_in_zone; then
            hide_dock
        fi
    ) &
    hide_timer_pid=$!
}

handle_event() {
    local event="$1"
    local data="$2"

    case "$event" in
        fullscreen)
            # fullscreen>>1 = entra a fullscreen, fullscreen>>0 = sale
            local fs="${data%%,*}"
            if [[ "$fs" == "1" || "$fs" == "2" ]]; then
                # Entra a fullscreen (1=fake fullscreen, 2=real fullscreen)
                if [[ "$prev_fullscreen" -eq 0 ]]; then
                    schedule_hide
                    prev_fullscreen=1
                fi
            else
                # Sale de fullscreen → mostrar el dock inmediatamente y cancelar ocultado
                if [[ "$prev_fullscreen" -eq 1 ]]; then
                    cancel_hide_timer
                    show_dock
                    prev_fullscreen=0
                fi
            fi
            ;;
    esac
}

# Conectar al socket2 y escuchar eventos
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
done
