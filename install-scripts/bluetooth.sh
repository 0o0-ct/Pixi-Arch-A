#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Bluetooth Stuff #

blue=(
  bluez
  bluez-utils
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

# Configurar el nombre del archivo de registro para incluir fecha y hora actuales
LOG="Install-Logs/install-$(date +%d-%H%M%S)_bluetooth.log"

# Bluetooth
printf "${NOTE} Instalando ${SKY_BLUE}Bluetooth${RESET} Packages...\n"
for BLUE in "${blue[@]}"; do
  install_package "$BLUE" "$LOG"
done

printf " Activating ${YELLOW}Bluetooth${RESET} Services...\n"
sudo systemctl enable --now bluetooth.service 2>&1 | tee -a "$LOG"

# Instalar Glass Bluetooth (glass-bt) nativo en /usr/local/bin y ~/.local/bin
if [ -f "$PARENT_DIR/files/glass-bt" ]; then
  printf "${NOTE} Instalando gestor nativo ${SKY_BLUE}glass-bt${RESET} en /usr/local/bin y ~/.local/bin...\n"
  sudo install -m 755 "$PARENT_DIR/files/glass-bt" /usr/local/bin/glass-bt 2>&1 | tee -a "$LOG"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$PARENT_DIR/files/glass-bt" "$HOME/.local/bin/glass-bt" 2>&1 | tee -a "$LOG"
elif [ -d "$PARENT_DIR/packages/glass-bt" ] && command -v cargo >/dev/null 2>&1; then
  printf "${NOTE} Compilando gestor nativo ${SKY_BLUE}glass-bt${RESET} desde el código fuente...\n"
  cargo build --release --manifest-path "$PARENT_DIR/packages/glass-bt/Cargo.toml" 2>&1 | tee -a "$LOG"
  if [ -f "$PARENT_DIR/packages/glass-bt/target/release/glass-bt" ]; then
    sudo install -m 755 "$PARENT_DIR/packages/glass-bt/target/release/glass-bt" /usr/local/bin/glass-bt 2>&1 | tee -a "$LOG"
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$PARENT_DIR/packages/glass-bt/target/release/glass-bt" "$HOME/.local/bin/glass-bt" 2>&1 | tee -a "$LOG"
  fi
fi

# Desinstalar y limpiar por completo paneles y paquetes Bluetooth antiguos (blueman, btcenter)
if pacman -Qq blueman >/dev/null 2>&1; then
  printf "${NOTE} Removiendo paquete obsoleto ${YELLOW}blueman${RESET} del sistema...\n"
  sudo pacman -Rns --noconfirm blueman 2>&1 | tee -a "$LOG" || true
fi

systemctl --user stop btcenter.service 2>/dev/null || true
systemctl --user disable btcenter.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/btcenter.service"
rm -f "$HOME/.config/systemd/user/graphical-session.target.wants/btcenter.service"
rm -rf "$HOME/.config/quickshell/btcenter"
rm -f "$HOME/.config/autostart/blueman.desktop"
rm -f "$HOME/.config/hypr/scripts/BluemanGlass.py"

# Redirigir cualquier llamada heredada de blueman-manager hacia glass-bt
mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/blueman-manager"
ln -sf "$HOME/.local/bin/glass-bt" "$HOME/.local/bin/blueman-manager"

# Instalar lanzadores .desktop modernos
mkdir -p "$HOME/.local/share/applications"
cat << 'DESK' > "$HOME/.local/share/applications/glass-bt.desktop"
[Desktop Entry]
Name=Bluetooth
GenericName=Gestor de Bluetooth
Comment=Gestor de Bluetooth Glassmorphism nativo GTK4
Exec=glass-bt
Icon=bluetooth
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
Keywords=bluetooth;blueman;bt;wireless;
DESK

cat << 'DESK' > "$HOME/.local/share/applications/blueman-manager.desktop"
[Desktop Entry]
Name=Bluetooth
GenericName=Gestor de Bluetooth
Comment=Gestor de Bluetooth Glassmorphism
Exec=glass-bt
Icon=bluetooth
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
Keywords=bluetooth;blueman;bt;wireless;
DESK

cat << 'DESK' > "$HOME/.local/share/applications/blueman-adapters.desktop"
[Desktop Entry]
Type=Application
Name=Bluetooth Adapters
NoDisplay=true
Hidden=true
DESK

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

printf "\n%.0s" {1..2}
