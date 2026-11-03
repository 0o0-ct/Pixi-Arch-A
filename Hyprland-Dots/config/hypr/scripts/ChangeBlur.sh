#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Script for changing blurs on the fly (Hyprland 0.57+ Lua)

notif="$HOME/.config/swaync/images"

STATE=$(hyprctl -j getoption decoration.blur.passes | jq ".int")

if [ "${STATE}" == "2" ]; then
	hyprctl eval 'hl.config({ decoration = { blur = { size = 2, passes = 1 } } })'
 	notify-send -e -u low -i "$notif/nota.png" " Menos desenfoque"
else
	hyprctl eval 'hl.config({ decoration = { blur = { size = 5, passes = 2 } } })'
  	notify-send -e -u low -i "$notif/ja.png" " Desenfoque normal"
fi
