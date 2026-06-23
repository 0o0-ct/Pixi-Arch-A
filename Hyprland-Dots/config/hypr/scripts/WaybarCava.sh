#!/usr/bin/env bash
# WaybarCava.sh — safer single-instance handling, cleanup, and robustness
# Original concept by 0o0-ct/Pixi-Arch-A; this variant focuses on lifecycle hardening.

set -euo pipefail

# Ensure cava exists
if ! command -v cava >/dev/null 2>&1; then
  echo "cava not found in PATH" >&2
  exit 1
fi

# 0..7 → ▁▂▃▄▅▆▇█
bar="▁▂▃▄▅▆▇█"
dict="s/;//g"
bar_length=${#bar}
for ((i = 0; i < bar_length; i++)); do
  dict+=";s/$i/${bar:$i:1}/g"
done

# Clean up any leftover waybar-cava config files and their corresponding cava processes from past runs
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
for conf in "$RUNTIME_DIR"/waybar-cava.*.conf; do
  if [[ -f "$conf" ]]; then
    # Find and kill the cava process running with this specific config file
    pid=$(pgrep -f "cava -p $conf" || true)
    if [[ -n "$pid" ]]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$conf"
  fi
done

# Unique temp config
config_file="$(mktemp "$RUNTIME_DIR/waybar-cava.XXXXXX.conf")"

# Cleanup function to kill the child cava process when this script exits
cava_pid=""
cleanup() {
  if [[ -n "$cava_pid" ]]; then
    kill "$cava_pid" 2>/dev/null || true
  fi
  rm -f "$config_file"
}
trap cleanup EXIT INT TERM

cat >"$config_file" <<EOF
[general]
framerate = 30
bars = 10

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

# Stream cava output and translate digits 0..7 to bar glyphs
cava -p "$config_file" | sed -u "$dict" &
cava_pid=$!

# Wait for the background job to finish
wait "$cava_pid"

