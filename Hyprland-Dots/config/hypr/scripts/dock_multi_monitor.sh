#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# dock_multi_monitor.sh — Lanza nwg-dock-hyprland en TODOS los monitores activos
#
# Detecta cada monitor conectado y lanza una instancia independiente del dock
# en la parte inferior de cada uno. Así todos los usuarios, tengan 1 o N
# monitores, ven el dock en todas sus pantallas.
#
# Requisitos:
#   - hyprctl (viene con Hyprland)
#   - nwg-dock-hyprland iniciado con -r (resident)

set -uo pipefail

[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && exit 1
[[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# --- Configuración del dock ------------------------------------------------
DOCK_POS="bottom"
DOCK_ALIGN="center"
DOCK_ICON_SIZE=48
DOCK_MARGIN_BOTTOM=16

# --- Detectar monitores activos -------------------------------------------
# hyprctl monitors devuelve bloques como:
#   Monitor "HDMI-A-1" (0x1234): 1920x1080@60.00Hz
#   active workspace: 1
#   ...
get_monitor_names() {
    # Hyprland 0.4x: Monitor "eDP-1" (0x1234)
    # Hyprland 0.57+: Monitor eDP-1 (ID 0):
    # Soportamos ambos formatos
    hyprctl monitors 2>/dev/null | grep -E '^Monitor ' | sed -E 's/^Monitor[[:space:]]+//; s/[[:space:]]*\(?ID[[:space:]]*[0-9]+\)?[[:space:]]*:$//; s/^"//; s/"$//'
}

# --- Función para lanzar el dock en un monitor -----------------------------
launch_dock_on_monitor() {
    local monitor_name="$1"
    local instance_id="$2"

    # Verificar si ya hay una instancia para este monitor
    if pgrep -f "nwg-dock-hyprland.*-o ${monitor_name}" >/dev/null 2>&1; then
        echo "[dock-multi] Ya hay una instancia en ${monitor_name}, omitiendo."
        return 0
    fi

    echo "[dock-multi] Lanzando dock en monitor ${monitor_name} (instancia ${instance_id})..."
    nohup nwg-dock-hyprland \
        -p "${DOCK_POS}" \
        -a "${DOCK_ALIGN}" \
        -i "${DOCK_ICON_SIZE}" \
        -mb "${DOCK_MARGIN_BOTTOM}" \
        -o "${monitor_name}" \
        -m \
        -r \
        >/dev/null 2>&1 &
}

# --- Lanza el dock en cada monitor ----------------------------------------
monitor_count=0
for mon in $(get_monitor_names); do
    monitor_count=$((monitor_count + 1))
    launch_dock_on_monitor "$mon" "$monitor_count"
done

if [[ "$monitor_count" -eq 0 ]]; then
    echo "[dock-multi] Advertencia: no se detectaron monitores."
    exit 1
fi

echo "[dock-multi] Dock lanzado en ${monitor_count} monitor(es)."

# --- Espera a que los docks estén listos y lanza los monitores ------------
sleep 2

# Monitor de fullscreen: oculta el dock en todos los monitores cuando hay fullscreen
if [[ -x "$HOME/.config/hypr/scripts/dock_fullscreen_monitor.sh" ]] && command -v socat >/dev/null 2>&1 \
   && ! pgrep -f 'dock_fullscreen_monitor.sh' >/dev/null 2>&1; then
    nohup "$HOME/.config/hypr/scripts/dock_fullscreen_monitor.sh" >/dev/null 2>&1 &
fi

# Monitor de hover: muestra el dock al pasar el ratón por la zona inferior
if [[ -x "$HOME/.config/hypr/scripts/dock_hover_monitor.sh" ]] && ! pgrep -f 'dock_hover_monitor.sh' >/dev/null 2>&1; then
    nohup "$HOME/.config/hypr/scripts/dock_hover_monitor.sh" >/dev/null 2>&1 &
fi

# Tooltip del dock: muestra comando al mantener el ratón 2s en la zona inferior
if [[ -x "$HOME/.config/hypr/scripts/dock_tooltip.sh" ]] && ! pgrep -f 'dock_tooltip.sh' >/dev/null 2>&1; then
    nohup "$HOME/.config/hypr/scripts/dock_tooltip.sh" >/dev/null 2>&1 &
fi

exit 0
