#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Servicios systemd de usuario para los paneles QuickShell
#
# Los paneles (audiocenter, btcenter, controlcenter, netcenter) deben estar
# anclados a graphical-session.target en lugar de default.target, para asegurar
# que arranquen cuando el compositor Wayland ya esté disponible.
#
# controlcenter implementa las notificaciones (CcNotifications.qml), por lo
# que swaync.service se desactiva y enmascara para evitar conflictos en D-Bus.

qs_panels=(audiocenter btcenter controlcenter netcenter)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || return 1 2>/dev/null || exit 1

if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_quickshell-units.log"

if ! command -v qs >/dev/null 2>&1; then
  printf "${ERROR} Quickshell (qs) no está instalado.\n" | tee -a "$LOG"
  exit 1
fi

SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

printf "${NOTE} Configurando servicios systemd para los paneles QuickShell...\n"

for panel in "${qs_panels[@]}"; do
  cat > "$SYSTEMD_DIR/$panel.service" << UNIT_EOF
[Unit]
Description=QuickShell Panel ($panel)
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/qs -c $panel
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT_EOF
  printf "${OK} Creado $SYSTEMD_DIR/$panel.service\n"
done

systemctl --user daemon-reload 2>/dev/null || true
for panel in "${qs_panels[@]}"; do
  systemctl --user enable "$panel.service" 2>&1 | tee -a "$LOG" || true
done

# Enmascarar swaync para que no colisione con el daemon de notificaciones de QuickShell
systemctl --user disable --now swaync.service 2>/dev/null || true
systemctl --user mask swaync.service 2>/dev/null || true
printf "${OK} swaync.service enmascarado en favor de quickshell controlcenter.\n"
