#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Screen Idle / Caffeine Toggle for Hyprland (15 min auto-lock vs Infinite screen on)

PROCESS="hypridle"
iDIR="$HOME/.config/swaync/images"

if [[ "${1:-}" == "status" ]]; then
    if pgrep -x "$PROCESS" >/dev/null 2>&1; then
        # Normal Mode (hypridle running, auto-lock active)
        printf '{"text":"󰔚 15m","class":"normal active","tooltip":"Modo Estándar: Bloqueo Automático en 15 min\\nHaz clic para cambiar a Modo Infinito (Nunca apagar)"}\n'
    else
        # Caffeine / Infinite Mode (hypridle killed, screen stays on forever)
        printf '{"text":"󰅶 ∞","class":"caffeine notactive activated","tooltip":"Modo Infinito (Cafeína): Pantalla SIEMPRE Encendida\\nNunca se apaga ni se bloquea. Haz clic para volver a 15 min"}\n'
    fi
elif [[ "${1:-}" == "toggle" ]]; then
    if pgrep -x "$PROCESS" >/dev/null 2>&1; then
        pkill -x "$PROCESS" || true
        pkill -RTMIN+9 waybar 2>/dev/null || true
        notify-send -u low -i "$iDIR/ja.png" "Modo Infinito Activado ☕" "La pantalla NUNCA se apagará ni se bloqueará."
    else
        hyprctl dispatch exec hypridle >/dev/null 2>&1 || nohup hypridle >/dev/null 2>&1 &
        sleep 0.2
        pkill -RTMIN+9 waybar 2>/dev/null || true
        notify-send -u low -i "$iDIR/ja.png" "Modo Estándar Activado ⏱️" "Bloqueo automático de pantalla tras 15 minutos."
    fi
else
    # Default to status if no argument
    "$0" status
fi
