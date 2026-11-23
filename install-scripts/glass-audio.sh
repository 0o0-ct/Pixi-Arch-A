#!/usr/bin/env bash
# Compila e instala el mezclador GTK4 desde el workspace de Pixi-Arch-A.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$REPO_DIR/packages"
INSTALL_DIR="${HOME}/.local/bin"

if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: instala Rust/Cargo antes de compilar glass-audio." >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"
printf 'Compilando glass-audio desde %s...\n' "$PACKAGE_DIR"
cargo build --release --manifest-path "$PACKAGE_DIR/Cargo.toml" -p glass-audio
install -m 755 "$PACKAGE_DIR/target/release/glass-audio" "$INSTALL_DIR/glass-audio"
printf 'Instalado: %s/glass-audio\n' "$INSTALL_DIR"
printf 'Abre el mezclador con: %s/glass-audio\n' "$INSTALL_DIR"
