#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Servicios systemd de usuario para los paneles QuickShell
#
# ¿Por qué existen estos ficheros .service?
# -----------------------------------------
# Los paneles (audiocenter, btcenter, controlcenter, netcenter) se arrancaban
# en Startup_Apps.conf con exec-once, PERO systemd los lanzaba por su cuenta
# (estaban WantedBy=default.target): podían nacer 11 segundos ANTES de que el
# compositor existiera y morir al conectar su capa de shell. Restart=always
# los revivía ~14s después, pero como procesos "zombie" de arranque.
#
# La solución es anclarlos a graphical-session.target, que uwsm activa en el
# instante correcto del login gráfico. Así el orden siempre es:
#   1) sesión gráfica lista  2) paneles arrancan.
#
# Este script también enmascara swaync.service: el panel controlcenter
# (CcNotifications.qml) YA reclama org.freedesktop.Notifications en D-Bus.
# Si swaync estuviera activo, ambos pelearían por el nombre y las
# notificaciones se comportarían de forma errática.

qs_panels=(audiocenter btcenter controlcenter netcenter)

## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || {
  echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"
  exit 1
}

# Cargar el script de funciones globales
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_quickshell-units.log"

# Requisitos: quickshell instalado y configs de los paneles presentes
if ! command -v qs >/dev/null 2>&1; then
  printf "${ERROR} Quickshell (qs) no está instalado. Ejecuta primero ${SKY_BLUE}install-scripts/quickshell.sh${RESET}\n" | tee -a "$LOG"
  exit 1
fi
if [ ! -d "$HOME/.config/quickshell" ]; then
  printf "${ERROR} No existe ~/.config/quickshell (configs de los paneles). Aplica los dots con ${SKY_BLUE}copy.sh${RESET} antes.\n" | tee -a "$LOG"
  exit 1
fi

# Crear los ficheros .service (uno por panel, solo si su config existe)
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

printf "${NOTE} Creando servicios systemd de usuario para los paneles QuickShell...\n"

for panel in "${qs_panels[@]}"; do
  if [ ! -d "$HOME/.config/quickshell/$panel" ]; then
    printf "${INFO} Config ${YELLOW}$panel${RESET} no encontrada; omitiendo su servicio.\n" | tee -a "$LOG"
    continue
  fi

  cat > "$SYSTEMD_DIR/$panel.service" << EOF
[Unit]
Description=QuickShell Panel ($panel)
# graphical-session.target se activa con uwsm justo cuando el compositor ya
# existe; evita la carrera de arranque de los paneles.
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/qs -c $panel
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF

  printf "${OK} Creado ${YELLOW}$SYSTEMD_DIR/$panel.service${RESET}\n"
done

# Recargar systemd de usuario y enlazar los servicios al target gráfico
systemctl --user daemon-reload
for panel in "${qs_panels[@]}"; do
  if [ -f "$SYSTEMD_DIR/$panel.service" ]; then
    systemctl --user reenable "$panel.service" 2>&1 | tee -a "$LOG"
    # Arrancarlo ahora SOLO si la sesión gráfica ya está activa (instalación
    # en caliente). En el próximo login lo hará graphical-session.target.
    if systemctl --user is-active --quiet graphical-session.target; then
      systemctl --user start "$panel.service" 2>&1 | tee -a "$LOG"
    fi
  fi
done

# Registrar los servicios para limpieza en copy.sh futuras (si aplica)
printf "${OK} Paneles QuickShell listos (anclados a graphical-session.target)\n"

# Mask swaync: el panel controlcenter ya es el servidor de notificaciones
systemctl --user disable --now swaync.service 2>/dev/null | tee -a "$LOG"
systemctl --user mask swaync.service 2>&1 | tee -a "$LOG"
printf "${OK} swaync.service deshabilitado y enmascarado (controlcenter gestiona las notificaciones)\n"
printf "${INFO} Para revertir: ${YELLOW}systemctl --user unmask swaync.service && systemctl --user enable --now swaync.service${RESET}\n"

printf "\n%.0s" {1..1}
