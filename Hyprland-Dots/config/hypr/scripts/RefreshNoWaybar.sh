#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Refresh helper used after a monitor-profile change, without touching Waybar.
#
# The old implementation killed rofi and restarted bare `qs`, which took down
# every QuickShell panel (control center, audio, network, overview) for a
# monitor reload.  Waybar, QuickShell and AGS all watch their own configs and
# receive their own targeted reloads; this helper only refreshes SwayNC's
# in-place config/CSS and the optional rainbow-border decoration.

set -uo pipefail

UserScripts="${HOME}/.config/hypr/UserScripts"

if pgrep -x swaync >/dev/null 2>&1 && command -v swaync-client >/dev/null 2>&1; then
  swaync-client -R -rs >/dev/null 2>&1 || true
fi

if [ -x "${UserScripts}/RainbowBorders.sh" ]; then
  "${UserScripts}/RainbowBorders.sh" >/dev/null 2>&1 &
fi

exit 0
