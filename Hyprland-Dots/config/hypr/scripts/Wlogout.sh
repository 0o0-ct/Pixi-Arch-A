#!/bin/bash
# 💫 Rofi-based Power Menu replacement for wlogout 💫

# Directories
icon_dir="$HOME/.config/wlogout/icons"
rasi_file="$HOME/.config/rofi/config-power.rasi"

# Check if rofi is running, kill it if so
if pgrep -x "rofi" > /dev/null; then
    pkill -x "rofi"
    exit 0
fi

# Launch rofi dmenu with all 6 options in a single echo statement
selected_option=$(echo -en "Lock\0icon\x1f$icon_dir/lock.png\nLogout\0icon\x1f$icon_dir/logout.png\nSuspend\0icon\x1f$icon_dir/sleep.png\nShutdown\0icon\x1f$icon_dir/power.png\nReboot\0icon\x1f$icon_dir/restart.png\nHibernate\0icon\x1f$icon_dir/hibernate.png\n" | rofi -dmenu -config "$rasi_file" -p "     " -selected-row 0)

# Execute actions based on selection
case "$selected_option" in
    *Lock*)
        $HOME/.config/hypr/scripts/LockScreen.sh
        ;;
    *Logout*)
        hyprctl dispatch exit 0
        ;;
    *Suspend*)
        systemctl suspend
        ;;
    *Shutdown*)
        systemctl poweroff
        ;;
    *Reboot*)
        systemctl reboot
        ;;
    *Hibernate*)
        systemctl hibernate
        ;;
esac
