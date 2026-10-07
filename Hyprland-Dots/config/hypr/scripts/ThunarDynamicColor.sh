#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Fast Thunar Launcher with Dynamic Folder Color Support

PAPIRUS_BIN="$HOME/.local/bin/papirus-folders"
if ! command -v "$PAPIRUS_BIN" &>/dev/null; then
    PAPIRUS_BIN="papirus-folders"
fi

# Si se solicita explícitamente cambiar color (--random o --color <c>), se ejecuta en segundo plano sin demorar la apertura
if [[ "${1:-}" == "--random" ]] && command -v "$PAPIRUS_BIN" &>/dev/null; then
    COLORS=("violet" "cyan" "indigo" "teal" "deeporange" "magenta" "red" "green" "pink" "nordic" "carmine" "yellow" "bluegrey")
    RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}
    nohup "$PAPIRUS_BIN" -C "$RANDOM_COLOR" >/dev/null 2>&1 &
    shift
elif [[ "${1:-}" == "--color" && -n "${2:-}" ]] && command -v "$PAPIRUS_BIN" &>/dev/null; then
    nohup "$PAPIRUS_BIN" -C "$2" >/dev/null 2>&1 &
    shift 2
fi

# Iniciar Thunar inmediatamente (0.03s de respuesta)
exec thunar "$@"
