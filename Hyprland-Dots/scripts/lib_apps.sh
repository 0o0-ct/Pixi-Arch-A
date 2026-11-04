#!/usr/bin/env bash
# Ayudantes para habilitar apps y selección de editor.

# Añade una línea única al final del fichero tolerando la ausencia de \n final.
# Si el archivo no termina en salto de línea, la exec-once se fusionaría con la
# anterior (bug visto: 'thunar --daemonexec-once = blueman-applet').
sa_append_once() {
  local file="$1"
  local line="$2"
  local present_re="${3:-}"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  # Normalizar \n final antes de añadir una exec-once nueva
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file" 2>/dev/null)" ]; then
    printf '\n' >>"$file"
  fi
  # Cadena fija: evita que el $ de $scriptsDir actúe como ancla de regex
  if [ -n "$present_re" ]; then
    grep -Eq -- "$present_re" "$file" && return 0
  elif grep -Fqx -- "$line" "$file"; then
    return 0
  fi
  printf '%s\n' "$line" >>"$file"
}

enable_asusctl() {
  local log="$1"
  if command -v asusctl >/dev/null 2>&1; then
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    sa_append_once "$OVERLAY_SA" 'exec-once = rog-control-center' '^\s*exec-once\s*=\s*rog-control-center'
  fi
}

enable_blueman() {
  local log="$1"
  if command -v blueman-applet >/dev/null 2>&1; then
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    sa_append_once "$OVERLAY_SA" 'exec-once = blueman-applet' '^\s*exec-once\s*=\s*(blueman-applet)'
  fi
}

enable_ags() {
  local log="$1"
  if command -v ags >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} AGS detectado - habilitando en scripts de inicio y actualización" 2>&1 | tee -a "$log"
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    sa_append_once "$OVERLAY_SA" 'exec-once = ags' '^\s*exec-once\s*=\s*ags'
    sed -i '/#ags -q && ags &/s/^#//' config/hypr/scripts/RefreshNoWaybar.sh
    sed -i '/#ags -q && ags &/s/^#//' config/hypr/scripts/Refresh.sh
  fi
}

enable_quickshell() {
  local log="$1"
  if command -v qs >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} Quickshell detectado - habilitando en scripts de inicio y actualización" 2>&1 | tee -a "$log"
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    sa_append_once "$OVERLAY_SA" 'exec-once = qs' '^\s*exec-once\s*=\s*qs(\s|$)'
    sed -i '/#pkill qs && qs &/s/^#//' config/hypr/scripts/RefreshNoWaybar.sh
    sed -i '/#pkill qs && qs &/s/^#//' config/hypr/scripts/Refresh.sh
  fi
}

ensure_keybinds_init() {
  local log="$1"
  local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
  local line='exec-once = $scriptsDir/KeybindsLayoutInit.sh'
  if grep -Fqx -- "$line" "$OVERLAY_SA" 2>/dev/null; then
    return 0
  fi
  sa_append_once "$OVERLAY_SA" "$line"
  echo "${INFO:-[INFO]} Añadido KeybindsLayoutInit.sh a la configuración de aplicaciones de inicio" 2>&1 | tee -a "$log"
}

install_terminal_configs() {
  local log="$1"

  # Ghostty
  local GHOSTTY_SRC="config/ghostty/ghostty.config"
  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local GHOSTTY_DEST="$GHOSTTY_DIR/config"
  if [ -f "$GHOSTTY_SRC" ]; then
    mkdir -p "$GHOSTTY_DIR"
    install -m 0644 "$GHOSTTY_SRC" "$GHOSTTY_DEST" 2>&1 | tee -a "$log"
    if [ -f "$GHOSTTY_DIR/wallust.conf" ]; then
      sed -i -E 's/^(\\s*palette\\s*=\\s*)([0-9]{1,2}):/\\1\\2=/' "$GHOSTTY_DIR/wallust.conf" 2>&1 | tee -a "$log" || true
    fi
  else
    echo "${ERROR:-[ERROR]} - No se encontró $GHOSTTY_SRC; omitiendo la instalación de la configuración de Ghostty." 2>&1 | tee -a "$log"
  fi

  # WezTerm
  local WEZTERM_SRC="config/wezterm/wezterm.lua"
  local WEZTERM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
  local WEZTERM_DEST="$WEZTERM_DIR/wezterm.lua"
  if [ -f "$WEZTERM_SRC" ]; then
    mkdir -p "$WEZTERM_DIR"
    install -m 0644 "$WEZTERM_SRC" "$WEZTERM_DEST" 2>&1 | tee -a "$log"
  else
    echo "${ERROR:-[ERROR]} - No se encontró $WEZTERM_SRC; omitiendo la instalación de la configuración de WezTerm." 2>&1 | tee -a "$log"
  fi
}

choose_default_editor() {
  local log="$1"
  local editor_set=0
  update_editor() {
    local editor=$1
    sed -i "s/#env = EDITOR,.*/env = EDITOR,$editor #default editor/" config/hypr/UserConfigs/01-UserDefaults.conf
    echo "${OK:-[OK]} El editor predeterminado se configuró como ${MAGENTA:-}$editor${RESET:-}." 2>&1 | tee -a "$log"
  }
  if command -v nvim &>/dev/null; then
    printf "${INFO:-[INFO]} Se detectó que ${MAGENTA:-}neovim${RESET:-} está instalado\n"
    update_editor "nvim"
    editor_set=1
  fi
  printf "\n"
  if [[ "$editor_set" -eq 0 ]] && command -v vim &>/dev/null; then
    printf "${INFO:-[INFO]} Se detectó que ${MAGENTA:-}vim${RESET:-} está instalado\n"
    update_editor "vim"
    editor_set=1
  fi
}
