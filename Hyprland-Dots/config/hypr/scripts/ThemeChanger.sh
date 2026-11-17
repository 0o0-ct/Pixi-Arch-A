#!/usr/bin/env bash
set -euo pipefail

# SPDX-FileCopyrightText: 2025-present Ahum Maitra theahummaitra@gmail.com
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Repository url : https://github.com/TheAhumMaitra/cautious-waddle
#
# Wallust built-in themes are applied through the same single-owner engine as
# wallpaper changes: pixi_colors.py extracts the theme palette, derives the M3
# roles, renders every consumer atomically and performs targeted reloads.
# This script must not run `wallust theme` or edit generated files directly.

require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s\n' "Missing dependency: $1" >&2
    exit 127
  }
}

require wallust
require rofi

have_notify() { command -v notify-send >/dev/null 2>&1; }

# Prompt for theme; guard -e on cancel
set +e
choice="$(wallust theme list \
  | sed -e '1d' -e 's/^- //' \
  | rofi -dmenu -i -p 'Select Global Theme')"
prompt_status=$?
set -e

if (( prompt_status != 0 )) || [[ -z "${choice}" ]]; then
  exit 0
fi

# Save a last-known-good profile before changing the theme identity.
if [ -x "$HOME/.config/hypr/scripts/ThemeProfileSave.sh" ]; then
  "$HOME/.config/hypr/scripts/ThemeProfileSave.sh" --quiet --force last-known-good \
    --tag "auto: pre-cambio, choice=${choice}" || true
fi

engine="$HOME/.config/hypr/scripts/WallustSwww.sh"
if [ ! -x "$engine" ]; then
  have_notify && notify-send -u critical -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Failed to apply theme" "WallustSwww.sh is missing or not executable"
  exit 1
fi

if "$engine" --theme "$choice"; then
  have_notify && notify-send -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Global theme changed" "Selected: ${choice}"
else
  have_notify && notify-send -u critical -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Failed to apply theme" "${choice}" \
    "See ~/.cache/pixi-colors/last-run.json"
  exit 1
fi
