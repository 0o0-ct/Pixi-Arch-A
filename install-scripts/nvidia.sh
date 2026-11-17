#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Nvidia Stuffs - Auto-detects GPU generation and installs correct driver #

detect_nvidia_driver() {
  local dev_id gpu_gen driver

  dev_id=$(lspci -nn | grep -i nvidia | grep -iE "VGA|3D" | grep -oP '10de:\K[0-9a-f]+' | head -1)
  gpu_desc=$(lspci -vnn | grep -i nvidia | grep -iE "VGA|3D" | sed 's/.*: //' | head -1)

  if [ -z "$dev_id" ]; then
    echo "nvidia-dkms"
    return
  fi

  local dec=$((16#${dev_id}))

  # Blackwell   (RTX 5000)  0x2800-0x29FF
  # Ada Lovelace (RTX 4000)  0x2600-0x27FF
  # Ampere      (RTX 3000)  0x2200-0x25FF
  # Turing      (RTX 2000)  0x1E00-0x1FFF + 0x2180-0x21FF
  if [ "$dec" -ge 7936 ] && [ "$dec" -le 8191 ] || [ "$dec" -ge 8576 ] && [ "$dec" -le 8703 ]; then
    # Turing (0x1F00-0x1FFF + 0x2180-0x21FF)
    gpu_gen="Turing (RTX 2000/GTX 1600)"
    driver="nvidia-open-dkms"
  elif [ "$dec" -ge 8704 ] && [ "$dec" -le 9727 ]; then
    # Ampere (0x2200-0x25FF)
    gpu_gen="Ampere (RTX 3000)"
    driver="nvidia-open-dkms"
  elif [ "$dec" -ge 9728 ] && [ "$dec" -le 10239 ]; then
    # Ada Lovelace (0x2600-0x27FF)
    gpu_gen="Ada Lovelace (RTX 4000)"
    driver="nvidia-open-dkms"
  elif [ "$dec" -ge 10240 ] && [ "$dec" -le 10751 ]; then
    # Blackwell (0x2800-0x29FF)
    gpu_gen="Blackwell (RTX 5000)"
    driver="nvidia-open-dkms"
  elif [ "$dec" -ge 6912 ] && [ "$dec" -le 7551 ]; then
    # Pascal (0x1B00-0x1D7F)
    gpu_gen="Pascal (GTX 1000)"
    driver="nvidia-dkms"
  elif [ "$dec" -ge 7168 ] && [ "$dec" -le 7423 ]; then
    # Maxwell 2 (0x1C00-0x1CFF)
    gpu_gen="Maxwell 2 (GTX 900)"
    driver="nvidia-dkms"
  elif [ "$dec" -ge 4032 ] && [ "$dec" -le 5119 ]; then
    # Kepler (0x0FC0-0x13FF)
    gpu_gen="Kepler (GTX 600-700)"
    driver="nvidia-470xx-dkms"
  else
    gpu_gen="${gpu_desc:-Desconocida}"
    driver="nvidia-dkms"
  fi

  echo "$driver|$gpu_gen"
}

detect_nvidia_driver_info=$(detect_nvidia_driver)
NVIDIA_DRIVER="${detect_nvidia_driver_info%%|*}"
GPU_GEN="${detect_nvidia_driver_info##*|}"

echo "${INFO} GPU NVIDIA detectada: ${SKY_BLUE}${GPU_GEN}${RESET}"
echo "${INFO} Controlador recomendado: ${SKY_BLUE}${NVIDIA_DRIVER}${RESET}"

nvidia_pkg=(
  "$NVIDIA_DRIVER"
  nvidia-settings
  nvidia-utils
  libva
  nvidia-prime
)

# Only add libva-nvidia-driver for supported GPUs
case "$NVIDIA_DRIVER" in
  nvidia-470xx-dkms|nvidia-390xx-dkms)
    ;;
  *)
    nvidia_pkg+=(libva-nvidia-driver)
    ;;
esac


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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_nvidia.log"


# nvidia stuff
printf "${YELLOW} Checking for other hyprland packages and remove if any..${RESET}\n"
if pacman -Qs hyprland > /dev/null; then
  printf "${YELLOW} Hyprland detected. removing to install Hyprland desde official repo...${RESET}\n"
    for hyprnvi in hyprland-git hyprland-nvidia hyprland-nvidia-git hyprland-nvidia-hidpi-git; do
    sudo pacman -R --noconfirm "$hyprnvi" 2>/dev/null | tee -a "$LOG" || true
    done
fi

# Install additional Nvidia packages
printf "${YELLOW} Instalando ${SKY_BLUE}Nvidia Packages and Linux headers${RESET}...\n"
for krnl in $(cat /usr/lib/modules/*/pkgbase); do
  for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
    install_package "$NVIDIA" "$LOG"
  done
done

# Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
  echo "Nvidia modules already included in /etc/mkinitcpio.conf" 2>&1 | tee -a "$LOG"
else
  sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf 2>&1 | tee -a "$LOG"
  echo "${OK} Nvidia modules added in /etc/mkinitcpio.conf"
fi

printf "\n%.0s" {1..1}
printf "${INFO} Rebuilding ${YELLOW}Initramfs${RESET}...\n" 2>&1 | tee -a "$LOG"
sudo mkinitcpio -P 2>&1 | tee -a "$LOG"

printf "\n%.0s" {1..1}

# Additional Nvidia steps
NVEA="/etc/modprobe.d/nvidia.conf"
if [ -f "$NVEA" ]; then
  printf "${INFO} Seems like ${YELLOW}nvidia_drm modeset=1 fbdev=1${RESET} is already added in your system..moving on."
  printf "\n"
else
  printf "\n"
  printf "${YELLOW} Adding options to $NVEA..."
  sudo echo -e "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a /etc/modprobe.d/nvidia.conf 2>&1 | tee -a "$LOG"
  printf "\n"
fi

# NVIDIA Power Management
printf "${YELLOW} Configuring NVIDIA Dynamic Power Management...${RESET}\n"
sudo echo -e "options nvidia NVreg_DynamicPowerManagement=0x02\noptions nvidia NVreg_EnableS0ixPowerManagement=1" | sudo tee /etc/modprobe.d/nvidia-power.conf 2>&1 | tee -a "$LOG"
sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>&1 | tee -a "$LOG"
echo 'ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"' | sudo tee /etc/udev/rules.d/80-nvidia-pm.rules 2>&1 | tee -a "$LOG"

# Enable nvidia-powerd for Dynamic Boost (critical for laptops with RTX 4000+)
printf "${YELLOW} Enabling NVIDIA Dynamic Boost (nvidia-powerd)...${RESET}\n"
sudo systemctl enable nvidia-powerd.service 2>&1 | tee -a "$LOG"
printf "${OK} NVIDIA Dynamic Power Management and Dynamic Boost configured.\n"


# Additional for GRUB users
if [ -f /etc/default/grub ]; then
    printf "${INFO} ${YELLOW}GRUB${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"
    
    # Check if nvidia-drm.modeset=1 is present
    if ! sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
        printf "${OK} nvidia-drm.modeset=1 added to /etc/default/grub\n" 2>&1 | tee -a "$LOG"
    fi

    # Check if nvidia_drm.fbdev=1 is present
    if ! sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
        printf "${OK} nvidia_drm.fbdev=1 added to /etc/default/grub\n" 2>&1 | tee -a "$LOG"
    fi

    # Regenerate GRUB configuration 
    if sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub || sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
       sudo grub-mkconfig -o /boot/grub/grub.cfg
       printf "${INFO} ${YELLOW}GRUB${RESET} configuration regenerated\n" 2>&1 | tee -a "$LOG"
    fi
  
    printf "${OK} Additional steps for ${YELLOW}GRUB${RESET} completed\n" 2>&1 | tee -a "$LOG"
fi

# Additional for systemd-boot users
if [ -f /boot/loader/loader.conf ]; then
    printf "${INFO} ${YELLOW}systemd-boot${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"
  
    backup_count=$(find /boot/loader/entries/ -type f -name "*.conf.bak" | wc -l)
    conf_count=$(find /boot/loader/entries/ -type f -name "*.conf" | wc -l)
  
    if [ "$backup_count" -ne "$conf_count" ]; then
        find /boot/loader/entries/ -type f -name "*.conf" | while read imgconf; do
            # Backup conf
            sudo cp "$imgconf" "$imgconf.bak"
            printf "${INFO} Backup created for systemd-boot loader: %s\n" "$imgconf" 2>&1 | tee -a "$LOG"
            
            # Clean up options and update with NVIDIA settings
            sdopt=$(grep -w "^options" "$imgconf" | sed 's/\b nvidia-drm.modeset=[^ ]*\b//g' | sed 's/\b nvidia_drm.fbdev=[^ ]*\b//g')
            sudo sed -i "/^options/c${sdopt} nvidia-drm.modeset=1 nvidia_drm.fbdev=1" "$imgconf" 2>&1 | tee -a "$LOG"
        done

        printf "${OK} Additional steps for ${YELLOW}systemd-boot${RESET} completed\n" 2>&1 | tee -a "$LOG"
    else
        printf "${NOTE} ${YELLOW}systemd-boot${RESET} is already configured...\n" 2>&1 | tee -a "$LOG"
    fi
fi

printf "\n%.0s" {1..2} 