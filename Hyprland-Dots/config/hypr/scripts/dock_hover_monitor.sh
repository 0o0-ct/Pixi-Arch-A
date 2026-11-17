#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# dock_hover_monitor.sh — Auto-ocultar el dock con hover en la parte inferior
#
# Comportamiento:
#   - Si NO hay ninguna ventana en fullscreen → el dock permanece SIEMPRE visible.
#   - Si hay una ventana en fullscreen → el dock se OCULTA, salvo que el ratón
#     entre en la zona inferior (donde está el dock), entonces se MUESTRA.
#   - Al salir el ratón de la zona y seguir habiendo fullscreen → se OCULTA de nuevo.
#
# Requisitos:
#   - nwg-dock-hyprland iniciado con -r (resident) para que responda a SIGRTMIN.
#   - hyprctl (viene con Hyprland).
#
# Señales usadas (iguales que dock_fullscreen_monitor.sh):
#   SIGRTMIN+2 = mostrar dock
#   SIGRTMIN+3 = ocultar dock

set -uo pipefail

# Salir si no estamos en una sesión de Hyprland
[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# --- Configuración ---------------------------------------------------------
INTERVAL=0.15        # segundos entre cada comprobación de la posición del ratón
TRIGGER_HEIGHT=40    # píxeles desde el borde inferior que activan la aparición
COOLDOWN_MS=400      # milisegundos mínimos entre cambios de estado (evita disparos en bucle)

# --- Estado ----------------------------------------------------------------
# 1 = visible, 0 = oculto. Asumimos visible al arrancar.
prev_visible=1
last_change_ms=0
prev_fullscreen=0

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
    # Formato de hyprctl cursorpos: "X/Y"
    echo "${pos##*/}" || echo "0"
}

# Devuelve la altura del monitor principal (0 si falla)
get_monitor_height() {
    local line
    line="$(hyprctl monitors 2>/dev/null | grep -E -o '[0-9]+x[0-9]+' | head -1)" || return 1
    echo "${line##*x}" || echo "0"
}

# Devuelve 1 si hay una ventana en fullscreen, 0 en caso contrario
is_fullscreen() {
    local fs
    fs="$(hyprctl activewindow 2>/dev/null | grep -E -o 'fullscreen:[[:space:]]*[0-9]+' | grep -E -o '[0-9]+$')" || echo "0"
    [[ "$fs" == "1" || "$fs" == "2" ]]
}

# Tiempo actual en milisegundos
now_ms() {
    echo $(($(date +%s%N) / 1000000))
}

# --- Bucle principal -------------------------------------------------------
main() {
    while true; do
        local now cursor_y mon_h in_zone fs want_visible elapsed

        now="$(now_ms)"
        cursor_y="$(get_cursor_y)"
        mon_h="$(get_monitor_height)"

        # ¿Está el ratón en la zona inferior de activación?
        in_zone=0
        if [[ -n "$cursor_y" && -n "$mon_h" && "$mon_h" -gt 0 ]]; then
            local threshold=$(( mon_h - TRIGGER_HEIGHT ))
            if [[ "$cursor_y" -ge "$threshold" ]]; then
                in_zone=1
            fi
        fi

        # ¿Hay fullscreen activo?
        if is_fullscreen; then
            fs=1
        else
            fs=0
        fi

        # Lógica de visibilidad:
        #   - Sin fullscreen → siempre visible
        #   - Con fullscreen → visible solo si el ratón está en la zona inferior
        want_visible=1
        if [[ "$fs" -eq 1 && "$in_zone" -eq 0 ]]; then
            want_visible=0
        fi

        # Aplicar solo si cambió el estado y pasó el cooldown
        if [[ "$want_visible" -ne "$prev_visible" ]]; then
            elapsed=$(( now - last_change_ms ))
            if [[ "$elapsed" -ge "$COOLDOWN_MS" ]]; then
                if [[ "$want_visible" -eq 1 ]]; then
                    show_dock
                else
                    hide_dock
                fi
                prev_visible=$want_visible
                last_change_ms=$now
            fi
        fi

        prev_fullscreen=$fs
        sleep "$INTERVAL"
    done
}

main "$@"
