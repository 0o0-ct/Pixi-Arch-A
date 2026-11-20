#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Screen Idle / Caffeine Toggle for Hyprland (auto-lock a los 10 min, aviso a los 9 min; o pantalla siempre encendida)

PROCESS="hypridle"
iDIR="$HOME/.config/swaync/images"

if [[ "${1:-}" == "status" ]]; then
    if pgrep -x "$PROCESS" >/dev/null 2>&1; then
        # Normal Mode (hypridle running, auto-lock active)
        printf '{"text":"󰔚 10m","class":"normal active","tooltip":"Modo Estándar: aviso a los 9 min y bloqueo a los 10 min\\nHaz clic para cambiar a Modo Infinito (Nunca apagar)"}\n'
    else
        # Caffeine / Infinite Mode (hypridle killed, screen stays on forever)
        printf '{"text":"󰅶 ∞","class":"caffeine notactive activated","tooltip":"Modo Infinito (Cafeína): Pantalla SIEMPRE Encendida\\nNunca se apaga ni se bloquea. Haz clic para volver a 9/10 min"}\n'
    fi
elif [[ "${1:-}" == "toggle" ]]; then
    if pgrep -x "$PROCESS" >/dev/null 2>&1; then
        pkill -x "$PROCESS" || true
        pkill -RTMIN+9 waybar 2>/dev/null || true
        notify-send -u low -i "$iDIR/ja.png" "Modo Infinito Activado ☕" "La pantalla NUNCA se apagará ni se bloqueará."
    else
        hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")' >/dev/null 2>&1 || nohup hypridle >/dev/null 2>&1 &
        sleep 0.2
        pkill -RTMIN+9 waybar 2>/dev/null || true
        notify-send -u low -i "$iDIR/ja.png" "Modo Estándar Activado ⏱️" "Aviso a los 9 minutos y bloqueo a los 10 minutos."
    fi
else
    # Default to status if no argument
    "$0" status
fi
