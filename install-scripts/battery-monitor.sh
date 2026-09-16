#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Battery Monitor and Low Battery Notification #

battery=(
  acpi
  libnotify
)


## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

# Cargar el script de funciones globales
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/install-$(date +%d-%H%M%S)_battery-monitor.log"

# Battery Monitor
printf "${NOTE} Instalando ${SKY_BLUE}Battery Monitor${RESET} Packages...\n"
for BAT in "${battery[@]}"; do
  install_package "$BAT" "$LOG"
done

# Create battery monitoring script
printf "${NOTE} Creating ${YELLOW}battery monitoring${RESET} script...\n"

BATTERY_SCRIPT="$HOME/.config/hypr/scripts/battery-monitor.sh"
mkdir -p "$HOME/.config/hypr/scripts"

cat > "$BATTERY_SCRIPT" << 'EOF'
#!/bin/bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
#
# Monitor de batería con AVISO SONORO
# -----------------------------------
# Avisa por notificación Y por sonido cuando la batería baja. El sonido es
# imprescindible: si estás lejos de la pantalla, una notificación no te enteras
# y el portátil se apaga sin avisar.
#
# Umbrales:
#     20%  -> 2 pitidos  (aviso)
#     15%  -> 3 pitidos  (aviso serio)
#     10%  -> 5 pitidos  (crítico) + RECORDATORIO cada 5 min mientras siga bajo
#
# El recordatorio del 10% existe porque el caso que hay que evitar es
# precisamente que el equipo se apague: si ignoras el primer aviso, vuelve.
#
# Sin dependencias externas: lee la batería directamente del kernel en
# /sys/class/power_supply/, así que NO necesita el paquete `acpi` (que no
# estaba instalado y habría hecho fallar la versión anterior).
#
# Limitación conocida: si tienes el audio silenciado o el volumen a cero, el
# pitido no se oirá. No hay forma de saltarse eso sin ser grosero.

set -uo pipefail

# ----------------------------- Configuración ------------------------------
LEVEL_WARN=20            # primer aviso
LEVEL_LOW=15             # aviso serio
LEVEL_CRITICAL=10        # crítico
CHECK_INTERVAL=60        # segundos entre comprobaciones
REMINDER_INTERVAL=300    # segundos entre recordatorios en crítico (5 min)

SOUND_DIR="/usr/share/sounds/freedesktop/stereo"
EVENT_WARN="dialog-warning"
EVENT_CRITICAL="alarm-clock-elapsed"

# Sonido propio del aviso (bateria-baja.mp3, ~5.5 s). Si no está, se cae a los
# sonidos del sistema para que el aviso siga sonando.
ALERT_SOUND="$HOME/.config/hypr/sounds/bateria-baja.mp3"

# El mp3 dura 1.79 s: repetido da el efecto "pip-pip-pip" de alarma.
# pasadas ya son 5-17 s de aviso. Ajusta aquí si lo quieres más insistente.
BEEPS_WARN=3
BEEPS_LOW=4
BEEPS_CRITICAL=6

# Estado: si ya avisamos de cada umbral, para no repetir cada minuto
DONE_WARN=0
DONE_LOW=0
DONE_CRITICAL=0
LAST_REMINDER=0

# ------------------------------- Utilidades -------------------------------

# Localiza la batería sin depender de acpi. En /sys puede llamarse BAT0 o BAT1.
find_battery() {
    local b
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] && { printf '%s' "$b"; return 0; }
    done
    return 1
}

# ¿Está enchufado? Buscamos cualquier adaptador de CA en línea.
is_plugged() {
    local a
    for a in /sys/class/power_supply/A{C,DP}*; do
        [ -r "$a/online" ] || continue
        [ "$(cat "$a/online" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

# Reproduce el sonido de aviso, opcionalmente forzando un dispositivo.
# Usa tu bateria-baja.mp3; si no estuviera, cae a los sonidos del sistema para
# que el aviso no se quede mudo.
play_once() {
    local device="${1:-}" file=""
    local dev_arg=()
    [ -n "$device" ] && dev_arg=(--device="$device")

    if [ -f "$ALERT_SOUND" ]; then
        file="$ALERT_SOUND"
    elif [ -f "$SOUND_DIR/$EVENT_WARN.oga" ]; then
        file="$SOUND_DIR/$EVENT_WARN.oga"
    fi

    if [ -n "$file" ] && command -v paplay >/dev/null 2>&1; then
        paplay "${dev_arg[@]}" --volume=65536 "$file" 2>/dev/null && return 0
    fi
    if [ -n "$file" ] && [ -z "$device" ] && command -v pw-play >/dev/null 2>&1; then
        pw-play "$file" 2>/dev/null && return 0
    fi
    if [ -z "$device" ] && command -v canberra-gtk-play >/dev/null 2>&1; then
        canberra-gtk-play -i "$EVENT_WARN" 2>/dev/null && return 0
    fi
    [ -z "$device" ] && printf '\a'
    return 0
}

# Reproduce el aviso en TODAS las salidas de audio, no solo en la de por
# defecto. Esto no es paranoia: en este equipo el sink por defecto era la
# salida HDMI de la GPU NVIDIA y los altavoces del portátil estaban al 10%
# (-60 dB), así que el aviso sonaba en el monitor y no se oía nada. Un aviso
# de batería crítica tiene que oírse esté donde esté enrutado el audio.
play_alert() {
    local sink

    if command -v pactl >/dev/null 2>&1; then
        while read -r sink; do
            [ -n "$sink" ] || continue
            play_once "$sink"
        done < <(pactl list short sinks 2>/dev/null | awk '{print $2}')
    else
        play_once
    fi
}

# beep <nº de pitidos>
beep() {
    local times="${1:-1}" i
    for ((i = 0; i < times; i++)); do
        play_alert
        [ "$i" -lt $((times - 1)) ] && sleep 0.5
    done
}

notify() {
    notify-send -u "$1" -i "$2" "$3" "$4" 2>/dev/null || true
}

# --------------------------------- Principal -------------------------------

BATTERY="$(find_battery)" || {
    echo "No se encontró ninguna batería. Este equipo es de sobremesa; saliendo."
    exit 0
}

echo "Monitorizando $BATTERY (avisos en ${LEVEL_WARN}% / ${LEVEL_LOW}% / ${LEVEL_CRITICAL}%)"

while true; do
    LEVEL="$(cat "$BATTERY/capacity" 2>/dev/null)"
    STATUS="$(cat "$BATTERY/status" 2>/dev/null)"

    if [ -n "$LEVEL" ] && [ "$STATUS" = "Discharging" ]; then

        if [ "$LEVEL" -le "$LEVEL_CRITICAL" ]; then
            NOW="$(date +%s)"
            # Primer aviso, o recordatorio si ya pasó el intervalo
            if [ "$DONE_CRITICAL" -eq 0 ] \
               || [ $((NOW - LAST_REMINDER)) -ge "$REMINDER_INTERVAL" ]; then
                beep "$BEEPS_CRITICAL"
                notify critical battery-caution "Batería crítica: ${LEVEL}%" \
                    "Queda muy poca batería. Conecta el cargador YA o el equipo se apagará."
                DONE_CRITICAL=1
                DONE_LOW=1
                DONE_WARN=1
                LAST_REMINDER="$NOW"
            fi

        elif [ "$LEVEL" -le "$LEVEL_LOW" ] && [ "$DONE_LOW" -eq 0 ]; then
            beep "$BEEPS_LOW"
            notify critical battery-low "Batería baja: ${LEVEL}%" \
                "Conecta el cargador pronto."
            DONE_LOW=1
            DONE_WARN=1

        elif [ "$LEVEL" -le "$LEVEL_WARN" ] && [ "$DONE_WARN" -eq 0 ]; then
            beep "$BEEPS_WARN"
            notify normal battery-low "Batería al ${LEVEL}%" \
                "Considera conectar el cargador."
            DONE_WARN=1
        fi

    else
        # Enchufado o cargando: rearmamos todos los avisos, así la próxima
        # descarga vuelve a avisar desde cero.
        if is_plugged || [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
            DONE_WARN=0
            DONE_LOW=0
            DONE_CRITICAL=0
            LAST_REMINDER=0
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
EOF

chmod +x "$BATTERY_SCRIPT"

printf "${OK} Battery monitoring script created at ${YELLOW}$BATTERY_SCRIPT${RESET}\n"

# Create systemd user service
printf "${NOTE} Creating ${YELLOW}systemd user service${RESET} for battery monitoring...\n"

SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/battery-monitor.service" << EOF
[Unit]
Description=Battery Level Monitor
After=graphical-session.target

[Service]
Type=simple
ExecStart=$BATTERY_SCRIPT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

printf "${OK} Systemd service created\n"

# Enable and start the service
printf "${NOTE} Habilitando and starting ${YELLOW}battery-monitor${RESET} service...\n"
systemctl --user daemon-reload
systemctl --user enable battery-monitor.service 2>&1 | tee -a "$LOG"
systemctl --user start battery-monitor.service 2>&1 | tee -a "$LOG"

printf "${OK} Battery monitor service is now running!\n"
printf "${INFO} You can check status with: ${YELLOW}systemctl --user status battery-monitor${RESET}\n"
printf "${INFO} To stop: ${YELLOW}systemctl --user stop battery-monitor${RESET}\n"
printf "${INFO} To disable: ${YELLOW}systemctl --user disable battery-monitor${RESET}\n"

printf "\n%.0s" {1..2}
