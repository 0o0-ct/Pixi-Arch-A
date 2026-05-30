#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##

# For Hyprlock
#pidof hyprlock || hyprlock -q

# Ensure weather cache is up-to-date before locking (Waybar/lockscreen readers)
bash "$HOME/.config/hypr/UserScripts/WeatherWrap.sh" >/dev/null 2>&1 &

# Detect and apply resolution-specific hyprlock config dynamically
bash "$HOME/.config/hypr/scripts/DetectResolutionHyprlock.sh"

loginctl lock-session

