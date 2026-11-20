#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Script de instalación del control de volumen en Rust

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUME_CONTROL_DIR="$SCRIPT_DIR/volume-control"
INSTALL_DIR="$HOME/.local/bin"

echo "=== Instalando Control de Volumen (Rust) ==="

# 1. Verificar dependencias
echo "[1/4] Verificando dependencias..."
if ! command -v cargo &> /dev/null; then
    echo "ERROR: cargo no encontrado. Instala Rust primero."
    exit 1
fi

if ! command -v pamixer &> /dev/null; then
    echo "WARNING: pamixer no encontrado. El control de volumen requiere pamixer."
fi

# 2. Compilar
echo "[2/4] Compilando..."
cd "$VOLUME_CONTROL_DIR"
cargo build --release

# 3. Instalar
echo "[3/4] Instalando..."
mkdir -p "$INSTALL_DIR"
cp "$VOLUME_CONTROL_DIR/target/release/volume-control" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/volume-control"
echo "Binario instalado en: $INSTALL_DIR/volume-control"

# 4. Verificar
echo "[4/4] Verificando..."
if command -v volume-control &> /dev/null; then
    echo "✓ Instalación completada exitosamente!"
    echo "  - CLI: volume-control --get"
    echo "  - GUI: volume-control"
    echo "  - Keybind: SUPER + V abre la GUI"
else
    echo "WARNING: volume-control no está en PATH. Agrega $INSTALL_DIR a tu PATH."
fi
