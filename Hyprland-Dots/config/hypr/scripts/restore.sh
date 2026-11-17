#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Rollback seguro: restaura el backup más reciente de ~/.config/hypr.bak-*

set -euo pipefail

BACKUP_DIR=$(ls -dt "$HOME"/.config/hypr.bak-* 2>/dev/null | head -1)

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ No hay backups válidos en ~/.config/hypr.bak-*"
    exit 1
fi

echo "🔄 Restaurando configuración desde: $BACKUP_DIR"
# Sincronizar de forma atómica y segura sobre ~/.config/hypr
cp -a "$BACKUP_DIR/." "$HOME/.config/hypr/"

echo "✅ Restaurado exitosamente. Recarga Hyprland con: hyprctl reload"
