#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##

# Evitar múltiples instancias simultáneas de hyprlock para no congelar la sesión
if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Actualizar el clima en segundo plano sin bloquear el bloqueo de pantalla
nohup bash "$HOME/.config/hypr/UserScripts/WeatherWrap.sh" >/dev/null 2>&1 &

# Detectar y aplicar la resolución adecuada para hyprlock (con timeout de seguridad)
timeout 1.5 bash "$HOME/.config/hypr/scripts/DetectResolutionHyprlock.sh" >/dev/null 2>&1 || true

# Notificar a loginctl/systemd para compatibilidad con eventos de suspensión del sistema
loginctl lock-session >/dev/null 2>&1 || true

# Ejecutar hyprlock con renderizado inmediato para que responda al instante
# y NUNCA ignore al usuario, incluso si hypridle está apagado (Modo Cafeína)
exec hyprlock --immediate-render

