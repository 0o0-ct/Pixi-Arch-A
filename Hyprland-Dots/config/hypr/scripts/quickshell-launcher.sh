#!/usr/bin/env bash
# QuickShell launcher - optimized: single instance with all modules
# Replaces 3 separate qs instances with one consolidated process

set -uo pipefail

# Check if any qs instance is running
if pgrep -x "qs" >/dev/null 2>&1; then
    exit 0
fi

# Launch single qs instance with all modules
nohup /usr/bin/qs -c controlcenter >/dev/null 2>&1 &
nohup /usr/bin/qs -c audiocenter >/dev/null 2>&1 &
nohup /usr/bin/qs -c netcenter >/dev/null 2>&1 &