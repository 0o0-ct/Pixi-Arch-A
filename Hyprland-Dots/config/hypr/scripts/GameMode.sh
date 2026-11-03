#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Game Mode. Turning off all animations (Hyprland 0.57+ Lua)

notif="$HOME/.config/swaync/images/ja.png"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

HYPRGAMEMODE=$(hyprctl -j getoption animations.enabled | jq '.int')
if [ "$HYPRGAMEMODE" = 1 ]; then
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })'
    hyprctl eval '_G.PixiGameModeRule:set_enabled(true)' >/dev/null 2>&1 || true
    swww kill
    notify-send -e -u low -i "$notif" " Modo de juego:" " habilitado"
    sleep 0.1
    exit
else
    (awww-daemon || swww-daemon) && swww img "$HOME/.config/rofi/.current_wallpaper" &
    sleep 0.1
    ${SCRIPTSDIR}/WallustSwww.sh
    sleep 0.5
    hyprctl reload
    ${SCRIPTSDIR}/Refresh.sh
    notify-send -e -u normal -i "$notif" " Modo de juego:" " deshabilitado"
    exit
fi
hyprctl reload
