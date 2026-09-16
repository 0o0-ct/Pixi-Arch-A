#!/usr/bin/env bash
# Screen Idle / Caffeine Toggle for Hyprland

PROCESS="hypridle"
iDIR="$HOME/.config/swaync/images"

if [[ "$1" == "status" ]]; then
    if pgrep -x "$PROCESS" >/dev/null; then
        # Normal Mode (hypridle running, auto-lock active)
        printf '{"text":"󰔚 15m","class":"normal","tooltip":"Modo Estándar: Bloqueo Automático en 15 min\\nHaz clic para cambiar a Modo Infinito (Nunca apagar)"}\n'
    else
        # Caffeine / Infinite Mode (hypridle killed, screen stays on forever)
        printf '{"text":"󰅶 ∞","class":"caffeine","tooltip":"Modo Infinito (Cafeína): Pantalla SIEMPRE Encendida\\nNunca se apaga ni se bloquea. Haz clic para volver a 15 min"}\n'
    fi
elif [[ "$1" == "toggle" ]]; then
    if pgrep -x "$PROCESS" >/dev/null; then
        pkill -x "$PROCESS" || true
        notify-send -u low -i "$iDIR/ja.png" "Modo Infinito Activado ☕" "La pantalla NUNCA se apagará ni se bloqueará."
    else
        hypridle >/dev/null 2>&1 &
        disown
        notify-send -u low -i "$iDIR/ja.png" "Modo Estándar Activado ⏱️" "Bloqueo automático de pantalla tras 15 minutos."
    fi
fi
