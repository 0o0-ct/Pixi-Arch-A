#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Instalación y configuración de la versión GTK4 de glass-audio.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG="${LOG:-/dev/stderr}"

if ! command -v cargo >/dev/null 2>&1; then
    echo "[WARN] Cargo no está instalado; se omite la compilación de glass-audio." | tee -a "$LOG"
    exit 0
fi

if cargo build --release --manifest-path "$REPO_DIR/packages/Cargo.toml" -p glass-audio 2>&1 | tee -a "$LOG"; then
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$REPO_DIR/packages/target/release/glass-audio" "$HOME/.local/bin/glass-audio"
    echo "[OK] glass-audio instalado en ~/.local/bin/glass-audio" | tee -a "$LOG"
else
    echo "[WARN] No se pudo compilar glass-audio; revisa dependencias GTK4/Audio y vuelve a ejecutar install-scripts/glass-audio.sh." | tee -a "$LOG"
fi
