#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# macOS Tahoe Theme: GTK Theme + Icons + SF Pro Fonts #

## ADVERTENCIA: ¡NO EDITES MÁS ALLÁ DE ESTA LÍNEA SI NO SABES LO QUE ESTÁS HACIENDO! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Error al cambiar al directorio $PARENT_DIR"; exit 1; }

if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_macos-theme.log"

# ─── 1. Dependencias ────────────────────────────────────────────────
macos_deps=(sassc git)

printf "${INFO} Instalando ${SKY_BLUE}dependencias del tema macOS${RESET}...\n"
for PKG in "${macos_deps[@]}"; do
  install_package "$PKG" "$LOG"
done

# ─── 2. MacTahoe GTK Theme ─────────────────────────────────────────
THEME_DIR="$HOME/.themes"

printf "${INFO} Instalando ${SKY_BLUE}MacTahoe GTK Theme${RESET}...\n"
if [ -d "$THEME_DIR/MacTahoe-Dark" ]; then
  echo "${OK} MacTahoe-Dark ya está instalado. Omitiendo..."
else
  TEMP_DIR=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$TEMP_DIR/MacTahoe-gtk-theme" 2>&1 | tee -a "$LOG"
  if [ -d "$TEMP_DIR/MacTahoe-gtk-theme" ]; then
    cd "$TEMP_DIR/MacTahoe-gtk-theme"
    ./install.sh -d "$THEME_DIR" 2>&1 | tee -a "$LOG"
    cd "$PARENT_DIR"
    echo "${OK} MacTahoe GTK Theme instalado en $THEME_DIR"
  else
    echo "${ERROR} No se pudo clonar MacTahoe-gtk-theme"
  fi
  rm -rf "$TEMP_DIR"
fi

# ─── 3. MacTahoe Icon Theme ────────────────────────────────────────
ICON_DIR="$HOME/.icons"

printf "${INFO} Instalando ${SKY_BLUE}MacTahoe Icon Theme${RESET}...\n"
if [ -d "$ICON_DIR/MacTahoe-dark" ]; then
  echo "${OK} MacTahoe icons ya están instalados. Omitiendo..."
else
  TEMP_DIR=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$TEMP_DIR/MacTahoe-icon-theme" 2>&1 | tee -a "$LOG"
  if [ -d "$TEMP_DIR/MacTahoe-icon-theme" ]; then
    cd "$TEMP_DIR/MacTahoe-icon-theme"
    ./install.sh -d "$ICON_DIR" 2>&1 | tee -a "$LOG"
    cd "$PARENT_DIR"
    echo "${OK} MacTahoe Icon Theme instalado en $ICON_DIR"
  else
    echo "${ERROR} No se pudo clonar MacTahoe-icon-theme"
  fi
  rm -rf "$TEMP_DIR"
fi

# ─── 4. SF Pro Fonts ───────────────────────────────────────────────
FONT_DIR="$HOME/.local/share/fonts"

printf "${INFO} Instalando ${SKY_BLUE}SF Pro Fonts${RESET}...\n"
if fc-list 2>/dev/null | grep -qi "SF Pro"; then
  echo "${OK} SF Pro ya está instalado. Omitiendo..."
else
  mkdir -p "$FONT_DIR"
  TEMP_DIR=$(mktemp -d)
  git clone --depth=1 https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git "$TEMP_DIR/SF-Pro" 2>&1 | tee -a "$LOG"
  if [ -d "$TEMP_DIR/SF-Pro" ]; then
    # Copiar variantes esenciales
    cp "$TEMP_DIR/SF-Pro"/SF-Pro-{Regular,Medium,Semibold,Bold}.otf "$FONT_DIR/" 2>/dev/null
    cp "$TEMP_DIR/SF-Pro"/SF-Pro-Rounded-{Regular,Medium,Semibold,Bold}.otf "$FONT_DIR/" 2>/dev/null
    cp "$TEMP_DIR/SF-Pro"/SF-Pro-Text-{Regular,Medium,Semibold,Bold}.otf "$FONT_DIR/" 2>/dev/null
    fc-cache -f "$FONT_DIR" 2>&1 | tee -a "$LOG"
    echo "${OK} SF Pro Fonts instaladas en $FONT_DIR"
  else
    echo "${ERROR} No se pudo clonar San-Francisco-Pro-Fonts"
  fi
  rm -rf "$TEMP_DIR"
fi

# ─── 5. GTK settings.ini ───────────────────────────────────────────
printf "${INFO} Configurando ${SKY_BLUE}GTK settings.ini${RESET}...\n"

for GTK_CONF in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
  mkdir -p "$GTK_CONF"
  if [ -f "$GTK_CONF/settings.ini" ]; then
    sed -i 's/^gtk-theme-name=.*/gtk-theme-name=MacTahoe-Dark/' "$GTK_CONF/settings.ini" 2>/dev/null
    sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=MacTahoe-Dark/' "$GTK_CONF/settings.ini" 2>/dev/null
    sed -i 's/^gtk-font-name=.*/gtk-font-name=SF Pro Text 11/' "$GTK_CONF/settings.ini" 2>/dev/null
    echo "${OK} settings.ini actualizado en $GTK_CONF"
  else
    cat > "$GTK_CONF/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=MacTahoe-Dark
gtk-icon-theme-name=MacTahoe-Dark
gtk-font-name=SF Pro Text 11
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF
    echo "${OK} settings.ini creado en $GTK_CONF"
  fi
done

# ─── 6. Matugen template: reemplazar placeholder con HOME real ──────
printf "${INFO} Configurando ${SKY_BLUE}matugen template${RESET}...\n"
MATUGEN_TPL="$HOME/.config/matugen/templates/gtk-colors.css"
if [ -f "$MATUGEN_TPL" ]; then
  sed -i "s|USER_HOME|$HOME|g" "$MATUGEN_TPL"
  echo "${OK} Ruta de tema MacTahoe actualizada en $MATUGEN_TPL"
else
  echo "${NOTE} No se encontró $MATUGEN_TPL (se copiará con los dotfiles)"
fi

printf "\n%.0s" {1..2}
echo "${OK} ${SKY_BLUE}macOS Tahoe Theme${RESET} instalado correctamente."
echo "${NOTE} Reinicia la sesión para aplicar todos los cambios."
printf "\n%.0s" {1..2}
