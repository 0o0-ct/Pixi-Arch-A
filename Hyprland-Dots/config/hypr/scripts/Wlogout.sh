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

# Options matching the icons exactly
lock="Lock\x1ficon\x1f$icon_dir/lock.png"
logout="Logout\x1ficon\x1f$icon_dir/logout.png"
suspend="Suspend\x1ficon\x1f$icon_dir/sleep.png"
shutdown="Shutdown\x1ficon\x1f$icon_dir/power.png"
reboot="Reboot\x1ficon\x1f$icon_dir/restart.png"
hibernate="Hibernate\x1ficon\x1f$icon_dir/hibernate.png"

# Launch rofi dmenu
selected_option=$(printf "%b\n" "$lock" "$logout" "$suspend" "$shutdown" "$reboot" "$hibernate" | rofi -dmenu -config "$rasi_file" -p "" -selected-row 0)

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
