#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Network Stuff (glass-net nativo + NetworkManager) #

net=(
  networkmanager
  gtk4
  gtk4-layer-shell
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

# Configurar el nombre del archivo de registro para incluir fecha y hora actual
LOG="Install-Logs/install-$(date +%d-%H%M%S)_network.log"

# NetworkManager
printf "${NOTE} Instalando ${SKY_BLUE}NetworkManager${RESET} Packages...\n"
for NET in "${net[@]}"; do
  install_package "$NET" "$LOG"
done

printf " Activating ${YELLOW}NetworkManager${RESET} Services...\n"
sudo systemctl enable --now NetworkManager.service 2>&1 | tee -a "$LOG"

# Instalar Glass Network (glass-net) nativo en /usr/local/bin y ~/.local/bin
if [ -f "$PARENT_DIR/files/glass-net" ]; then
  printf "${NOTE} Instalando gestor nativo ${SKY_BLUE}glass-net${RESET} en /usr/local/bin y ~/.local/bin...\n"
  sudo install -m 755 "$PARENT_DIR/files/glass-net" /usr/local/bin/glass-net 2>&1 | tee -a "$LOG"
  install -m 755 "$PARENT_DIR/files/glass-net" "$HOME/.local/bin/glass-net" 2>&1 | tee -a "$LOG"
elif [ -f "$PARENT_DIR/packages/glass-net/target/release/glass-net" ]; then
  printf "${NOTE} Compilando ${SKY_BLUE}glass-net${RESET} desde fuente...\n"
  (cd "$PARENT_DIR/packages/glass-net" && cargo build --release) 2>&1 | tee -a "$LOG"
  sudo install -m 755 "$PARENT_DIR/packages/glass-net/target/release/glass-net" /usr/local/bin/glass-net 2>&1 | tee -a "$LOG"
  install -m 755 "$PARENT_DIR/packages/glass-net/target/release/glass-net" "$HOME/.local/bin/glass-net" 2>&1 | tee -a "$LOG"
else
  printf "${WARN} No se encontró binario ni fuentes de glass-net, omitiendo...\n" | tee -a "$LOG"
fi

# Desactivar el autostart de nm-applet (reemplazado por glass-net)
printf "${NOTE} Desactivando autostart de ${YELLOW}nm-applet${RESET} (reemplazado por glass-net)...\n"
mkdir -p "$HOME/.config/autostart"
cat << 'DESK' > "$HOME/.config/autostart/nm-applet.desktop"
[Desktop Entry]
Type=Application
Name=nm-applet
Exec=/usr/bin/true
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
Comment=Reemplazado por glass-net (gestor de red glass nativo)
DESK
pkill -f "nm-applet" 2>/dev/null || true

# Desactivar el panel quickshell netcenter (delegado a glass-net)
printf "${NOTE} Desactivando panel ${YELLOW}netcenter${RESET} (delegado a glass-net)...\n"
systemctl --user stop netcenter.service 2>/dev/null || true
systemctl --user disable netcenter.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/netcenter.service"
rm -f "$HOME/.config/systemd/user/graphical-session.target.wants/netcenter.service"
systemctl --user daemon-reload 2>/dev/null || true

# Lanzador .desktop de glass-net
mkdir -p "$HOME/.local/share/applications"
cat << 'DESK' > "$HOME/.local/share/applications/glass-net.desktop"
[Desktop Entry]
Name=Red
GenericName=Gestor de Red
Comment=Gestor Wi-Fi/Ethernet/VPN Glassmorphism nativo GTK4
Exec=glass-net
Icon=network-wireless
Terminal=false
Type=Application
Categories=Settings;Network;
Keywords=network;wifi;ethernet;vpn;red;glass;
DESK

# ── Autostart de daemons glass (abren al instante con SIGUSR1) ──
mkdir -p "$HOME/.config/autostart"
cat << 'DESK' > "$HOME/.config/autostart/glass-bt.desktop"
[Desktop Entry]
Type=Application
Name=Glass Bluetooth Daemon
Comment=Precarga glass-bt oculto para apertura instantánea
Exec=glass-bt --hidden
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
Categories=Settings;HardwareSettings;
Keywords=bluetooth;glass;daemon;
DESK
cat << 'DESK' > "$HOME/.config/autostart/glass-net.desktop"
[Desktop Entry]
Type=Application
Name=Glass Network Daemon
Comment=Precarga glass-net oculto para apertura instantánea
Exec=glass-net --hidden
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
Categories=Settings;Network;
Keywords=network;wifi;glass;daemon;
DESK

printf "\n${OK} ${SKY_BLUE}glass-net${RESET} instalado. Lánzalo desde el click del módulo network de waybar, ${YELLOW}SUPER + SHIFT + N${RESET} o el botón 󰤨 de swaync.\n" | tee -a "$LOG"
