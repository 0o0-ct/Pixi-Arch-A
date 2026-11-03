#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# for changing Hyprland Layouts (Master or Dwindle) on the fly
# Hyprland 0.57+ Lua: the J/K/O keys are layout-aware in lua/keybinds.lua,
# so this script only has to switch the layout.

notif="$HOME/.config/swaync/images/ja.png"

LAYOUT=$(hyprctl -j getoption general.layout | jq -r '.str')

case "$LAYOUT" in
"master")
  hyprctl eval 'hl.config({ general = { layout = "dwindle" } })'
  notify-send -e -u low -i "$notif" " Dwindle Layout"
  ;;
"dwindle")
  hyprctl eval 'hl.config({ general = { layout = "master" } })'
  notify-send -e -u low -i "$notif" " Master Layout"
  ;;
*) ;;
esac
