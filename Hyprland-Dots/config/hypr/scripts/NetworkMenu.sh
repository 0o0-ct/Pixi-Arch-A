#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# NetworkMenu.sh — Menú de red interactivo con Rofi en diseño Glass Monet Frosted

set -euo pipefail

ROFI_THEME="$HOME/.config/rofi/themes/[Glass] Monet Frosted.rasi"
PIDIR="$HOME/.config/swaync/images"
SEPARATOR="────────────────────────────────────────"

notify() {
    local icon="${1:-nota.png}"
    local title="${2:-Red}"
    local msg="${3:-}"
    if [ -f "$PIDIR/$icon" ]; then
        notify-send -u low -i "$PIDIR/$icon" "$title" "$msg" 2>/dev/null || true
    else
        notify-send -u low "$title" "$msg" 2>/dev/null || true
    fi
}

wifi_radio() {
    nmcli radio wifi 2>/dev/null || echo "disabled"
}

# Si el wifi está apagado pero se abre el menú, activar
if [ "$(wifi_radio)" = "disabled" ]; then
    nmcli radio wifi on 2>/dev/null || true
    notify "nota.png" "WiFi" "Activando adaptador WiFi..."
    sleep 1
fi

# Disparar rescan en segundo plano para mantener la caché fresca sin bloquear la interfaz
nmcli device wifi rescan &>/dev/null &

# Conexiones activas
active_eth=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-3-ethernet:' | cut -d: -f2 | head -1 || true)
active_wifi=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2 | head -1 || true)

# Redes guardadas / conocidas en NetworkManager
known_conns=()
while IFS= read -r conn; do
    [ -z "$conn" ] && continue
    known_conns+=("$conn")
done < <(nmcli -t -f TYPE,NAME connection show 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2 | sort -u || true)

# Construir lista de opciones para Rofi
options=()
declare -A action_map

add_option() {
    options+=("$1")
    action_map["$1"]="$2"
}

# 1. Mostrar conexión Ethernet si está activa
if [ -n "$active_eth" ]; then
    add_option "󰈀  Ethernet: $active_eth  (conectado)" "ETH:$active_eth"
fi

# 2. Obtener lista de redes WiFi al alcance
declare -A seen_ssids

# Primero detectar la señal de la red activa
if [ -n "$active_wifi" ]; then
    active_sig=$(nmcli -t -f IN-USE,SSID,SIGNAL device wifi list 2>/dev/null | grep '^\*:' | cut -d: -f3 | head -1 || true)
    [ -z "$active_sig" ] && active_sig="100"
    add_option "󰤨  $active_wifi  ·${active_sig}%  (conectado)" "ACTIVE:$active_wifi"
    seen_ssids["$active_wifi"]=1
fi

# 3. Listar redes WiFi al alcance (ordenadas por intensidad de señal)
while IFS=: read -r in_use ssid signal security; do
    [ -z "$ssid" ] && continue
    [ -n "${seen_ssids[$ssid]:-}" ] && continue
    seen_ssids["$ssid"]=1

    sec_icon=""
    [ -n "$security" ] && [ "$security" != "--" ] && sec_icon=" 󰌾"

    # Verificar si es una red ya guardada
    is_known=false
    for k in "${known_conns[@]}"; do
        if [ "$k" = "$ssid" ]; then
            is_known=true
            break
        fi
    done

    if [ "$is_known" = true ]; then
        add_option "󰤥  $ssid  ·${signal}%${sec_icon}" "CONNECT:$ssid"
    else
        add_option "󰤮  $ssid  ·${signal}%${sec_icon}" "NEW:$ssid"
    fi
done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | sort -t: -k3 -rn || true)

add_option "$SEPARATOR" "SEP"

# 4. Acciones y Controles
if [ -n "$active_wifi" ]; then
    add_option "󰤭  Desconectar de $active_wifi" "DISCONNECT"
fi

if [ "$(wifi_radio)" = "enabled" ]; then
    add_option "󰤩  Apagar adaptador WiFi" "RADIO_OFF"
else
    add_option "󰤨  Encender adaptador WiFi" "RADIO_ON"
fi

add_option "󰤨  Configuración avanzada (nmtui)" "NMTUI"
add_option "󰑐  Refrescar lista de redes" "RESCAN"

# Toggle: si ya está abierto, cerrarlo al volver a hacer clic
if pidof rofi >/dev/null 2>&1; then
    killall rofi
    exit 0
fi

# Mostrar menú Rofi con el tema Glass Monet Frosted
list_input=$(printf '%s\n' "${options[@]}")
chosen=$(echo "$list_input" | rofi -dmenu -i \
    -theme "$ROFI_THEME" \
    -m -1 \
    -p "Redes WiFi" \
    -mesg "󰌾 = Con contraseña | 󰤥 = Red conocida | 󰤨 = Conectado" \
    -no-custom || true)

[ -z "$chosen" ] && exit 0
action="${action_map[$chosen]:-}"
[ -z "$action" ] || [ "$action" = "SEP" ] && exit 0

# Ejecución de la acción seleccionada
case "$action" in
    ACTIVE:*)
        notify "ja.png" "WiFi" "Ya estás conectado a ${action#ACTIVE:}"
        ;;
    CONNECT:*)
        ssid="${action#CONNECT:}"
        notify "nota.png" "WiFi" "Conectando a $ssid..."
        if nmcli connection up "$ssid" &>/dev/null; then
            notify "ja.png" "WiFi" "Conectado exitosamente a $ssid"
        else
            notify "error.png" "WiFi" "No se pudo conectar a $ssid"
        fi
        ;;
    NEW:*)
        ssid="${action#NEW:}"
        PASS_THEME="$HOME/.config/rofi/themes/[Glass] Password.rasi"
        [ ! -f "$PASS_THEME" ] && PASS_THEME="$ROFI_THEME"
        pass=$(echo "" | rofi -dmenu -password \
            -theme "$PASS_THEME" \
            -m -1 \
            -mesg "Introduce la contraseña para $ssid:" || true)
        [ -z "$pass" ] && exit 0
        notify "nota.png" "WiFi" "Conectando a $ssid..."
        if nmcli device wifi connect "$ssid" password "$pass" &>/dev/null; then
            notify "ja.png" "WiFi" "Conectado exitosamente a $ssid"
        else
            notify "error.png" "WiFi" "Contraseña incorrecta o error al conectar"
        fi
        ;;
    DISCONNECT)
        if [ -n "$active_wifi" ]; then
            nmcli connection down "$active_wifi" &>/dev/null || true
            notify "nota.png" "WiFi" "Desconectado de $active_wifi"
        fi
        ;;
    RADIO_OFF)
        nmcli radio wifi off
        notify "nota.png" "WiFi" "Adaptador WiFi apagado"
        ;;
    RADIO_ON)
        nmcli radio wifi on
        notify "nota.png" "WiFi" "Adaptador WiFi encendido"
        ;;
    NMTUI)
        kitty -e nmtui 2>/dev/null || alacritty -e nmtui 2>/dev/null || xterm -e nmtui 2>/dev/null || true
        ;;
    RESCAN)
        notify "nota.png" "WiFi" "Escaneando redes cercanas..."
        nmcli device wifi rescan &>/dev/null || true
        sleep 1.5
        exec "$0"
        ;;
esac
