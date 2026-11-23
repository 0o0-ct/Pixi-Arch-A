#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Instalación de volume-control (Rust + Iced). No asigna SUPER+V:
# ese atajo pertenece al panel de QuickShell.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VOLUME_CONTROL_DIR="$SCRIPT_DIR/volume-control"
INSTALL_DIR="$HOME/.local/bin"

printf 'Compilando volume-control...\n'
(cd "$VOLUME_CONTROL_DIR" && cargo build --release)
mkdir -p "$INSTALL_DIR"
install -m 755 "$VOLUME_CONTROL_DIR/target/release/volume-control" "$INSTALL_DIR/volume-control"
printf 'Instalado: %s/volume-control (sin atajo SUPER+V)\n' "$INSTALL_DIR"
