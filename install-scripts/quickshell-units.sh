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

# Paneles activos de QuickShell (btcenter reemplazado por el gestor nativo glass-bt)
qs_panels=(audiocenter controlcenter netcenter)

# Limpiar servicio residual de btcenter si existía
systemctl --user stop btcenter.service 2>/dev/null || true
systemctl --user disable btcenter.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/btcenter.service"
rm -f "$HOME/.config/systemd/user/graphical-session.target.wants/btcenter.service"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cambiar el directorio de trabajo al directorio padre del script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || exit 1

# Cargar el script de funciones globales
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
    echo "Error al cargar Global_functions.sh"
    exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_quickshell-units.log"

echo "${INFO} Creando unidades systemd para paneles QuickShell...${RESET}" | tee -a "$LOG"

# Desactivar y enmascarar swaync (conflicto D-Bus con controlcenter)
echo "${INFO} Enmascarando swaync.service...${RESET}" | tee -a "$LOG"

mkdir -p ~/.config/systemd/user

# Crear el archivo de enmascaramiento
cat > ~/.config/systemd/user/swaync.service << 'EOF'
[Unit]
Description=Sway Notification Center

[Service]
ExecStart=
ExecStart=/bin/false

[Install]
WantedBy=default.target
EOF

echo "${INFO} Enmascaramiento creado. Para aplicar: systemctl --user daemon-reload && systemctl --user enable --now swaync.service" | tee -a "$LOG"
