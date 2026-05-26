#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Disk Space Monitor #

disk=(
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_disk-monitor.log"

# Disk Monitor
printf "${NOTE} Instalando ${SKY_BLUE}Disk Monitor${RESET} Packages...\n"
for DISK in "${disk[@]}"; do
  install_package "$DISK" "$LOG"
done

# Create disk monitoring script
printf "${NOTE} Creating ${YELLOW}disk space monitoring${RESET} script...\n"

DISK_SCRIPT="$HOME/.config/hypr/scripts/disk-monitor.sh"
mkdir -p "$HOME/.config/hypr/scripts"

cat > "$DISK_SCRIPT" << 'EOF'
#!/bin/bash
# Disk Space Monitoring Script
# Monitors disk usage and sends notifications

# Configuration
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
CHECK_INTERVAL=300  # Check every 5 minutes

# Track notification state
declare -A NOTIFIED_WARNING
declare -A NOTIFIED_CRITICAL

while true; do
    # Get disk usage for all mounted filesystems
    df -h | grep '^/dev/' | while read -r line; do
        DEVICE=$(echo "$line" | awk '{print $1}')
        MOUNT=$(echo "$line" | awk '{print $6}')
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        
        # Skip if usage is not a number
        if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        # Check disk usage
        if [ "$USAGE" -ge "$DISK_CRITICAL_THRESHOLD" ]; then
            if [ "${NOTIFIED_CRITICAL[$MOUNT]}" != "true" ]; then
                notify-send -u critical -i drive-harddisk "Critical Disk Space" "Mount point $MOUNT is ${USAGE}% full!\nDevice: $DEVICE"
                NOTIFIED_CRITICAL[$MOUNT]="true"
                NOTIFIED_WARNING[$MOUNT]="true"
            fi
        elif [ "$USAGE" -ge "$DISK_WARNING_THRESHOLD" ]; then
            if [ "${NOTIFIED_WARNING[$MOUNT]}" != "true" ]; then
                notify-send -u normal -i drive-harddisk "Low Disk Space" "Mount point $MOUNT is ${USAGE}% full\nDevice: $DEVICE"
                NOTIFIED_WARNING[$MOUNT]="true"
            fi
        else
            # Reset notifications when usage drops
            if [ "$USAGE" -lt $((DISK_WARNING_THRESHOLD - 5)) ]; then
                NOTIFIED_WARNING[$MOUNT]="false"
                NOTIFIED_CRITICAL[$MOUNT]="false"
            fi
        fi
    done
    
    sleep "$CHECK_INTERVAL"
done
EOF

chmod +x "$DISK_SCRIPT"

printf "${OK} Disk monitoring script created at ${YELLOW}$DISK_SCRIPT${RESET}\n"

# Create systemd user service
printf "${NOTE} Creating ${YELLOW}systemd user service${RESET} for disk monitoring...\n"

SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/disk-monitor.service" << EOF
[Unit]
Description=Disk Space Monitor
After=graphical-session.target

[Service]
Type=simple
ExecStart=$DISK_SCRIPT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

printf "${OK} Systemd service created\n"

# Enable and start the service
printf "${NOTE} Habilitando and starting ${YELLOW}disk-monitor${RESET} service...\n"
systemctl --user daemon-reload
systemctl --user enable disk-monitor.service 2>&1 | tee -a "$LOG"
systemctl --user start disk-monitor.service 2>&1 | tee -a "$LOG"

printf "${OK} Disk monitor service is now running!\n"
printf "${INFO} You can check status with: ${YELLOW}systemctl --user status disk-monitor${RESET}\n"
printf "${INFO} View disk usage: ${YELLOW}df -h${RESET}\n"

printf "\n%.0s" {1..2}
