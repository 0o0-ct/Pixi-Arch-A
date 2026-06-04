#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
  if [ -e "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
  fi
}

# Kill already running processes
_ps=(waybar rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done

# added since wallust sometimes not applying
killall -SIGUSR2 waybar
# Added sleep for GameMode causing multiple waybar
sleep 0.1

# quit ags & relaunch ags
#ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs &

# some process to kill
for pid in $(pidof waybar rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Restart waybar
sleep 0.1
waybar &

# Dynamically adjust swaync position and size based on active Waybar layout
positionX="right"
positionY="top"
width=450
height=720

if [ -L "$HOME/.config/waybar/config" ]; then
  layout_name=$(basename "$(readlink -f "$HOME/.config/waybar/config")")
  
  if [[ "$layout_name" == *"[TOP & BOT]"* ]]; then
    positionX="right"
    positionY="bottom"
    width=450
    height=720
  elif [[ "$layout_name" == *"[BOT & Left]"* || "$layout_name" == *"[BOT & LEFT]"* ]]; then
    positionX="left"
    positionY="bottom"
    width=450
    height=720
  elif [[ "$layout_name" == *"[BOT & Right]"* || "$layout_name" == *"[BOT & RIGHT]"* ]]; then
    positionX="right"
    positionY="bottom"
    width=450
    height=720
  elif [[ "$layout_name" == *"[TOP & Left]"* || "$layout_name" == *"[TOP & LEFT]"* ]]; then
    positionX="left"
    positionY="top"
    width=450
    height=720
  elif [[ "$layout_name" == *"[TOP & Right]"* || "$layout_name" == *"[TOP & RIGHT]"* ]]; then
    positionX="right"
    positionY="top"
    width=450
    height=720
  elif [[ "$layout_name" == *"[LEFT]"* ]]; then
    positionX="left"
    positionY="bottom"
    width=720
    height=450
  elif [[ "$layout_name" == *"[RIGHT]"* ]]; then
    positionX="right"
    positionY="bottom"
    width=720
    height=450
  elif [[ "$layout_name" == *"[BOT]"* ]]; then
    positionX="right"
    positionY="bottom"
    width=450
    height=720
  elif [[ "$layout_name" == *"[TOP]"* ]]; then
    positionX="right"
    positionY="top"
    width=450
    height=720
  fi
fi

if [ -f "$HOME/.config/swaync/config.json" ] && which jq >/dev/null 2>&1; then
  jq --arg px "$positionX" --arg py "$positionY" --argjson w "$width" --argjson h "$height" '.positionX = $px | .positionY = $py | ."control-center-width" = $w | ."control-center-height" = $h' "$HOME/.config/swaync/config.json" > "$HOME/.config/swaync/config.json.tmp" && mv "$HOME/.config/swaync/config.json.tmp" "$HOME/.config/swaync/config.json"
fi

# relaunch swaync
sleep 0.3
swaync >/dev/null 2>&1 &
# reload swaync
swaync-client --reload-config

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  ${UserScripts}/RainbowBorders.sh &
fi

exit 0
