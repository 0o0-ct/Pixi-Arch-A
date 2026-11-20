#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Hyprland Packages #

# edit your packages desired here. 
# WARNING! If you remove packages here, dotfiles may not work properly.
# and also, ensure that packages are present in AUR and official Arch Repo

# add packages wanted here
Extra=(

)

hypr_package=( 
  #aylurs-gtk-shell
  bc
  cliphist
  curl 
  ffmpegthumbnailer
  file-roller
  flatpak
  gjs
  grim 
  gvfs 
  gvfs-afc
  gvfs-dnssd
  gvfs-gphoto2
  gvfs-mtp
  gvfs-smb
  hypridle
  hyprlock
  hyprpolkitagent
  hyprsunset
  imagemagick
  inxi 
  jq
  kitty
  kvantum
  libspng
  matugen
  nano  
  network-manager-applet 
  pacman-contrib
  pamixer 
  papirus-icon-theme
  pavucontrol
  playerctl
  poppler-glib
  python-requests
  python-pyquery
  qt5ct
  qt6ct
  qt6-svg
  quickshell
  rofi-wayland
  slurp 
  socat # needed by dock_fullscreen_monitor.sh
  swappy 
  swaync 
  swww
  unzip # needed later
  wallust 
  waybar
  wget
  wl-clipboard
  wlogout
  xdg-user-dirs
  xdg-utils 
  yad
)

# Paquetes esenciales (necesarios para funcionalidad básica)
hypr_package_essential=(
  brightnessctl 
  power-profiles-daemon
  thermald
  pacman-contrib
)

# Paquetes de monitoreo/sistema (opcionales - consumen recursos si se ejecutan en background)
hypr_package_monitoring=(
  btop
  cava
  nvtop
  gnome-system-monitor
  resources
)

# Paquetes multimedia/utilidades (opcionales)
hypr_package_media_utils=(
  loupe
  fastfetch
  mousepad 
  mpv
  mpv-mpris 
  nwg-look
  nwg-displays
  qalculate-gtk
  yt-dlp
)

# List of packages to uninstall as it conflicts some packages
uninstall=(
  aylurs-gtk-shell
  dunst
  cachyos-hyprland-settings
  mako
  rofi
  wallust-git
  rofi-lbonn-wayland
  rofi-lbonn-wayland-git
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_hypr-pkgs.log"

# conflicting packages removal
overall_failed=0
printf "\n%s - ${SKY_BLUE}Removing some packages${RESET} as it conflicts with KooL's Hyprland Dots \n" "${NOTE}"
for PKG in "${uninstall[@]}"; do
  uninstall_package "$PKG" 2>&1 | tee -a "$LOG"
  if [ $? -ne 0 ]; then
    overall_failed=1
  fi
done

if [ $overall_failed -ne 0 ]; then
  echo -e "${ERROR} Some packages failed to uninstall. Por favor revisa the log."
fi

printf "\n%.0s" {1..1}

# Instalación de paquetes principales (siempre requeridos)
printf "\n%s - Instalando ${SKY_BLUE}paquetes principales de Hyprland${RESET} .... \n" "${NOTE}"

for PKG1 in "${hypr_package[@]}" "${hypr_package_essential[@]}" "${Extra[@]}"; do
  install_package "$PKG1" "$LOG"
done

# Preguntar por paquetes de monitoreo (opcionales)
if whiptail --title "Paquetes de Monitoreo (Opcional)" --yesno \
"¿Instalar herramientas de monitoreo del sistema?\n\n\
btop, cava, nvtop, gnome-system-monitor, resources\n\n\
NOTA: Estos consumen recursos si se ejecutan en segundo plano.\n\
Se recomienda NO instalarlos en hardware modesto o laptops." 15 80; then
    printf "\n%s - Instalando ${SKY_BLUE}herramientas de monitoreo${RESET} .... \n" "${NOTE}"
    for PKG1 in "${hypr_package_monitoring[@]}"; do
        install_package "$PKG1" "$LOG"
    done
else
    echo "${INFO} Omitiendo herramientas de monitoreo (ahorro de recursos)" | tee -a "$LOG"
fi

# Preguntar por paquetes multimedia/utilidades (opcionales)
if whiptail --title "Paquetes Multimedia/Utilidades (Opcional)" --yesno \
"¿Instalar utilidades multimedia y extras?\n\n\
loupe, fastfetch, mousepad, mpv, mpv-mpris, nwg-look, nwg-displays, qalculate-gtk, yt-dlp\n\n\
Útiles pero no esenciales para el funcionamiento básico." 15 80; then
    printf "\n%s - Instalando ${SKY_BLUE}utilidades multimedia${RESET} .... \n" "${NOTE}"
    for PKG1 in "${hypr_package_media_utils[@]}"; do
        install_package "$PKG1" "$LOG"
    done
else
    echo "${INFO} Omitiendo utilidades multimedia extras" | tee -a "$LOG"
fi

# Enable thermal and power profiles services
printf "\n%s - Habilitando servicios ${SKY_BLUE}thermald y power-profiles-daemon${RESET}...\n" "${NOTE}"
sudo systemctl enable --now thermald.service 2>&1 | tee -a "$LOG" || true
sudo systemctl enable --now power-profiles-daemon.service 2>&1 | tee -a "$LOG" || true

printf "\n%.0s" {1..2}
