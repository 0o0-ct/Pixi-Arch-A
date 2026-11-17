#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# dock_tooltip.sh — Tooltip emergente sobre el dock al mantener el ratón 2s en la zona inferior
#
# Comportamiento:
#   - Si el ratón está quieto en la zona inferior (~40 px borde inferior) durante 2 segundos
#     → se muestra un notify-send con el comando para mostrar/ocultar el dock
#   - La notificación dura 3 segundos y desaparece sola
#   - Cooldown de 10 segundos para no spammear al usuario

set -uo pipefail

[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1

# --- Configuración ---------------------------------------------------------
INTERVAL=0.2           # segundos entre comprobaciones
HOVER_TIME=2           # segundos que debe mantenerse el ratón en la zona
TOOLTIP_DURATION=3000  # milisegundos que dura la notificación
TRIGGER_HEIGHT=40      # píxeles desde el borde inferior
COOLDOWN=10            # segundos entre notificaciones (evita spam)

# --- Estado ----------------------------------------------------------------
hover_start_ms=0
last_tooltip_ms=0
prev_in_zone=0

# --- Funciones -------------------------------------------------------------

now_ms() {
    echo $(( $(date +%s%N) / 1000000 ))
}

get_cursor_y() {
    hyprctl cursorpos 2>/dev/null | awk -F/ '{print $2}' || echo "0"
}

get_monitor_height() {
    hyprctl monitors 2>/dev/null | grep -E -o '[0-9]+x[0-9]+' | head -1 | awk -Fx '{print $2}' || echo "0"
}

cursor_in_zone() {
    local y h threshold
    y="$(get_cursor_y)"
    h="$(get_monitor_height)"
    [[ -n "$y" && -n "$h" && "$h" -gt 0 ]] || return 1
    threshold=$(( h - TRIGGER_HEIGHT ))
    [[ "$y" -ge "$threshold" ]]
}

show_tooltip() {
    notify-send \
        -t "$TOOLTIP_DURATION" \
        -a "nwg-dock" \
        -i "preferences-desktop" \
        "💡 Dock nwg-dock" \
        "SUPER + CTRL + D — mostrar / ocultar dock" \
        2>/dev/null || true
}

# --- Bucle principal -------------------------------------------------------
main() {
    while true; do
        local now in_zone hover_ms elapsed

        now="$(now_ms)"

        if cursor_in_zone; then
            in_zone=1
        else
            in_zone=0
        fi

        # Detectar cuando el ratón entra en la zona
        if [[ "$in_zone" -eq 1 && "$prev_in_zone" -eq 0 ]]; then
            hover_start_ms="$now"
        fi

        # Si lleva suficiente tiempo quieto en la zona, mostrar tooltip
        if [[ "$in_zone" -eq 1 ]]; then
            hover_ms=$(( now - hover_start_ms ))
            if [[ "$hover_ms" -ge $(( HOVER_TIME * 1000 )) ]]; then
                elapsed=$(( now - last_tooltip_ms ))
                if [[ "$elapsed" -ge $(( COOLDOWN * 1000 )) ]]; then
                    show_tooltip
                    last_tooltip_ms="$now"
                fi
            fi
        fi

        prev_in_zone="$in_zone"
        sleep "$INTERVAL"
    done
}

main "$@"
