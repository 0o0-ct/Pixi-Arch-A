#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# NetworkMenu.sh — Menú WiFi rápido con Rofi (tema Glass Monet Frosted)

ROFI_THEME="$HOME/.config/rofi/themes/[Glass] Monet Frosted.rasi"
PIDIR="$HOME/.config/swaync/images"
SEPARATOR="────────────────────────────────────────"

notify() {
    notify-send -u normal -i "$PIDIR/${1:-nota.png}" "${2:-Red}" "${3:-}" 2>/dev/null || true
}

wifi_radio() { nmcli -g WIFI radio 2>/dev/null || echo "disabled"; }

# Activar WiFi si está apagado (sin bloquear)
if [ "$(wifi_radio)" = "disabled" ]; then
    nmcli radio wifi on 2>/dev/null || true
    notify "nota.png" "WiFi" "Activando adaptador..."
fi

# Estado actual
active_wifi=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1 | head -1 || true)
active_eth=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-3-ethernet$' | cut -d: -f1 | head -1 || true)

# Redes guardadas
known_conns=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1 | sort -u || true)

# UNA sola llamada a nmcli con caché (rápido: ~30ms)
wifi_list=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null || true)

# Construir lista
options=()
declare -A action_map
add_option() { options+=("$1"); action_map["$1"]="$2"; }

# Ethernet activa
[ -n "$active_eth" ] && add_option "󰈀  Ethernet: $active_eth  (conectado)" "ETH:$active_eth"

# Red WiFi activa (señal de la misma caché)
seen=()
if [ -n "$active_wifi" ]; then
    active_sig=$(echo "$wifi_list" | grep "^\*:" | grep ":$active_wifi:" | cut -d: -f3 | head -1)
    [ -z "$active_sig" ] && active_sig="?"
    add_option "󰤨  $active_wifi  ·${active_sig}%  (conectado)" "ACTIVE:$active_wifi"
    seen+=("$active_wifi")
fi

# Redes en rango (con subtitulo de seguridad)
while IFS=: read -r in_use ssid signal security; do
    [ -z "$ssid" ] && continue
    [[ " ${seen[*]} " == *" $ssid "* ]] && continue
    seen+=("$ssid")

    sec_label="Abierta"
    [ -n "$security" ] && [ "$security" != "--" ] && sec_label="${security%% *}"
    [ -z "$sec_label" ] && sec_label="Abierta"

    is_known=false
    [[ "$known_conns" == *"$ssid"* ]] && is_known=true

    if [ "$is_known" = true ]; then
        add_option "󰤥  $ssid  ·${signal}%  |  ${sec_label}" "CONNECT:$ssid"
    else
        add_option "󰤮  $ssid  ·${signal}%  |  ${sec_label}" "NEW:$ssid"
    fi
done < <(echo "$wifi_list" | sort -t: -k3 -rn)

add_option "$SEPARATOR" "SEP"

# Controles
[ -n "$active_wifi" ] && add_option "󰤭  Desconectar de $active_wifi" "DISCONNECT"
if [ "$(wifi_radio)" = "enabled" ]; then
    add_option "󰤩  Apagar WiFi" "RADIO_OFF"
else
    add_option "󰤨  Encender WiFi" "RADIO_ON"
fi
add_option "󰤨  Editor (nmtui)" "NMTUI"
add_option "󰑐  Refrescar redes" "RESCAN"

# Mostrar menú
chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i \
    -theme "$ROFI_THEME" \
    -p "Redes WiFi" \
    -mesg "󰌾 = Contraseña | 󰤥 = Conocida | 󰤨 = Conectado" \
    -no-custom 2>/dev/null) || true

[ -z "$chosen" ] && exit 0
action="${action_map[$chosen]:-}"
[ -z "$action" ] && exit 0

# Verificar conexión activa (rápido: 8s timeout, verificacion eficiente)
wait_connection() {
    local ssid="$1" i=0
    while [ $i -lt 16 ]; do
        nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -qxF "$ssid:802-11-wireless" && return 0
        sleep 0.5
        i=$((i + 1))
    done
    return 1
}

# IP real del dispositivo WiFi
has_ip() {
    local dev
    dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep ':wifi:connected' | cut -d: -f1 | head -1 || true)
    [ -z "$dev" ] && return 1
    ip -4 addr show "$dev" 2>/dev/null | grep -q 'inet '
}

# Resultado en messagebox Rofi (con estilo)
show_result() {
    local status="$1" title="$2" message="$3"
    local icon="ja.png"
    [ "$status" = "error" ] && icon="error.png"
    notify "$icon" "$title" "$message"
    printf '%s\n' "$message" | rofi -dmenu \
        -theme "$ROFI_THEME" \
        -p "$title" \
        -mesg "$message" \
        -markup \
        -no-custom \
        -only-match 2>/dev/null || true
}

case "$action" in
    ACTIVE:*)
        notify "ja.png" "WiFi" "Ya conectado a ${action#ACTIVE:}"
        ;;
    CONNECT:*)
        ssid="${action#CONNECT:}"
        notify "nota.png" "WiFi" "Conectando a $ssid..."
        if nmcli connection up "$ssid" >/dev/null 2>&1 && wait_connection "$ssid"; then
            has_ip && show_result "ok" "Conectado ✓" "Te conectaste a $ssid con IP asignada" \
                   || show_result "ok" "Conectado" "Estás en $ssid (esperando IP...)"
        else
            show_result "error" "Error" "No se pudo conectar a $ssid"
        fi
        ;;
    NEW:*)
        ssid="${action#NEW:}"
        # Detectar seguridad de la red elegida
        sec=$(echo "$wifi_list" | grep -F ":$ssid:" | grep -v '^\*:' | cut -d: -f4 | head -1)
        sec_label="Abierta"
        [ -n "$sec" ] && [ "$sec" != "--" ] && sec_label="${sec%% *}"
        PASS_THEME="$HOME/.config/rofi/themes/[Glass] Password.rasi"
        [ ! -f "$PASS_THEME" ] && PASS_THEME="$ROFI_THEME"
        # Escapar markup del SSID (para &, <, >)
        ssid_esc="${ssid//&/&amp;}"; ssid_esc="${ssid_esc//</&lt;}"; ssid_esc="${ssid_esc//>/&gt;}"
        info_msg=$(printf '󰌾  <b>Contraseña</b>\n<b>Red:</b> %s\n<b>Seguridad:</b> %s' "$ssid_esc" "$sec_label")
        pass=$(printf '\n' | rofi -dmenu -password \
            -theme "$PASS_THEME" \
            -p "Contraseña" \
            -mesg "$info_msg" 2>/dev/null) || true
        [ -z "$pass" ] && exit 0
        notify "nota.png" "WiFi" "Verificando contraseña..."
        if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 && wait_connection "$ssid"; then
            has_ip && show_result "ok" "Conectado ✓" "Contraseña correcta. Conectado a $ssid" \
                   || show_result "ok" "Conectado" "Contraseña correcta (esperando IP...)"
        else
            show_result "error" "Contraseña incorrecta" "La contraseña no es válida para $ssid. Intenta de nuevo."
        fi
        ;;
    DISCONNECT)
        [ -n "$active_wifi" ] && nmcli connection down "$active_wifi" >/dev/null 2>&1 || true
        notify "nota.png" "WiFi" "Desconectado"
        ;;
    RADIO_OFF) nmcli radio wifi off >/dev/null 2>&1; notify "nota.png" "WiFi" "WiFi apagado" ;;
    RADIO_ON)  nmcli radio wifi on  >/dev/null 2>&1; notify "nota.png" "WiFi" "WiFi encendido" ;;
    NMTUI) kitty -e nmtui >/dev/null 2>&1 || alacritty -e nmtui >/dev/null 2>&1 || true ;;
    RESCAN)
        notify "nota.png" "WiFi" "Escaneando..."
        nmcli device wifi rescan >/dev/null 2>&1 || true
        sleep 1
        exec "$0"
        ;;
esac
exit 0
