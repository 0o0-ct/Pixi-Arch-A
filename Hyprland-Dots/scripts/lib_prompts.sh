#!/usr/bin/env bash
# User interaction helpers extracted desde copy.sh. Each helper echoes state or sets
# globals deliberately para minimizar side effects.

# Detect keyboard layout via localectl or setxkbmap.
prompt_detect_layout() {
  if command -v localectl >/dev/null 2>&1; then
    local layout
    layout=$(localectl status --no-pager | awk '/X11 Layout/ {print $3}')
    [ -n "$layout" ] && { echo "$layout"; return; }
  fi
  if command -v setxkbmap >/dev/null 2>&1; then
    local layout
    layout=$(setxkbmap -query | awk '/layout/ {print $2}')
    [ -n "$layout" ] && { echo "$layout"; return; }
  fi
  echo "(unset)"
}

# Confirm or set keyboard layout; escribe kb_layout en la config Lua INSTALADA
# (no en el árbol del repo). El valor debe conservar comillas y coma finales
# para que lua/settings.lua siga siendo Lua válido.
prompt_keyboard_layout() {
  local layout="$1"
  local log="$2"

  if [ "$layout" = "(unset)" ] || [ -z "$layout" ]; then
    layout="es,us"
  fi
  # sanear para Lua: solo letras, dígitos, coma, guion, más y guion bajo
  layout=$(printf '%s' "$layout" | tr -cd 'a-zA-Z0-9,_+-')
  [ -z "$layout" ] && layout="es,us"

  printf "${NOTE} Detectando la distribución de teclado para preparar la configuración adecuada de Hyprland\n"
  local live_settings="$HOME/.config/hypr/lua/settings.lua"
  if [ -f "$live_settings" ]; then
    awk -v layout="$layout" '/kb_layout = "/ {$0 = "        kb_layout = \"" layout "\","} 1' "$live_settings" >"$live_settings.tmp"
    if mv "$live_settings.tmp" "$live_settings"; then
      echo "${OK} kb_layout ${MAGENTA}$layout${RESET} configurada en la configuración Lua instalada." 2>&1 | tee -a "$log"
    else
      rm -f "$live_settings.tmp"
      echo "${WARN} No se pudo escribir kb_layout en $live_settings." 2>&1 | tee -a "$log"
    fi
  else
    echo "${WARN} $live_settings no encontrado, omitiendo configuración de teclado." 2>&1 | tee -a "$log"
  fi
}

# Prompt for resolution choice; echoes "< 1440p" or "≥ 1440p".
prompt_resolution_choice() {
  local choice
  while true; do
    echo "${INFO:-[INFO]} Selecciona la resolución del monitor para el escalado:"
    echo "  1) < 1440p   (DPI bajo; pantallas más pequeñas)"
    echo "  2) ≥ 1440p   (predeterminado; 1440p/2k/4k)"

    if ! read -r -p "${CAT} Introduce el número de tu elección (1 o 2): " choice </dev/tty; then
      echo "${ERROR} No se pudo leer la entrada (tty no disponible)."
      continue
    fi
    echo "${INFO:-[INFO]} Introdujiste: '$choice'"
    case "$choice" in
      1) echo "< 1440p"; return ;;
      2) echo "≥ 1440p"; return ;;
      *) echo "${ERROR} Elección no válida. Por favor introduce 1 para < 1440p o 2 para ≥ 1440p." ;;
    esac
  done
}

# Prompt for 12H clock; sets waybar/hyprlock/SDDM changes when accepted.
prompt_clock_12h() {
  local log="$1"
  echo "${INFO} Configurando automáticamente el formato de reloj de 12H (AM/PM)..." 2>&1 | tee -a "$log"

  # waybar clocks — sobre la COPIA INSTALADA, no el repo
  local WAYBAR_MODULES_LIVE="$HOME/.config/waybar/Modules"
  [ -f "$WAYBAR_MODULES_LIVE" ] || { echo "${WARN} $WAYBAR_MODULES_LIVE no encontrado, omitiendo reloj." 2>&1 | tee -a "$log"; return; }
  sed -i 's#^\(\s*\)//\("format": " {:%I:%M %p}",\) #\1\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)\("format": " {:%H:%M:%S}",\) #\1//\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)\("format": "  {:%H:%M}",\) #\1//\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)//\("format": "{:%I:%M %p - %d/%b}",\) #\1\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)\("format": "{:%H:%M - %d/%b}",\) #\1//\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)//\("format": "{:%B | %a %d, %Y | %I:%M %p}",\) #\1\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)\("format": "{:%B | %a %d, %Y | %H:%M}",\) #\1//\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)//\("format": "{:%A, %I:%M %P}",\) #\1\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true
  sed -i 's#^\(\s*\)\("format": "{:%a %d | %H:%M}",\) #\1//\2#g' "$WAYBAR_MODULES_LIVE" 2>&1 | tee -a "$log" || true

  # hyprlock: aplicar a TODAS las variantes de resolución SOBRE la copia
  # instalada (el árbol del repo permanece intacto)
  local HYPRLOCK_ANY=0
  local HYPRLOCK_FILE
  for HYPRLOCK_FILE in "$HOME"/.config/hypr/hyprlock.conf "$HOME"/.config/hypr/hyprlock-*.conf; do
    [ -f "$HYPRLOCK_FILE" ] || continue
    # sed -i sustituiría un symlink por un archivo real; el variant al que apunta
    # ya lleva el sed aplicado, así que nos saltamos el enlace.
    [ -L "$HYPRLOCK_FILE" ] && continue
    HYPRLOCK_ANY=1
    sed -i 's/^\s*text = cmd\[update:1000\] echo "\$(date +"%H")"/# &/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
    sed -i 's/^\(\s*\)# *text = cmd\[update:1000\] echo "\$(date +"%I")" #AM\/PM/\1    text = cmd\[update:1000\] echo "\$(date +"%I")" #AM\/PM/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
    sed -i 's/^\s*text = cmd\[update:1000\] echo "\$(date +"%S")"/# &/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
    sed -i 's/^\(\s*\)# *text = cmd\[update:1000\] echo "\$(date +"%S %p")" #AM\/PM/\1    text = cmd\[update:1000\] echo "\$(date +"%S %p")" #AM\/PM/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
  done
  if [ "$HYPRLOCK_ANY" -eq 0 ]; then
    echo "${WARN} Plantillas de hyprlock no encontradas; omitiendo las ediciones del formato de reloj de 12H" 2>&1 | tee -a "$log"
  fi

  if [ "${EXPRESS_MODE:-0}" -eq 0 ]; then
    apply_sddm_12h_format "/usr/share/sddm/themes/simple-sddm" "$log"
    apply_sddm_12h_format "/usr/share/sddm/themes/simple_sddm_2" "$log"
    apply_sddm_12h_format_sequoia "/usr/share/sddm/themes/sequoia_2" "$log"
  else
    echo "${NOTE:-[NOTE]} Modo exprés: omitiendo ediciones de SDDM 12H para evitar avisos de sudo." 2>&1 | tee -a "$log"
  fi
  echo "${OK} Formato de 12H configurado con éxito en los relojes de waybar y SDDM." 2>&1 | tee -a "$log"
}

apply_sddm_12h_format() {
  local sddm_directory="$1"
  local log="$2"
  if [ -d "$sddm_directory" ]; then
    echo "Editando ${SKY_BLUE}$sddm_directory${RESET} al formato de 12H" 2>&1 | tee -a "$log"
    if ! sudo -n sed -i 's|^## HourFormat="hh:mm AP"|HourFormat="hh:mm AP"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log"; then
      echo "${WARN:-[WARN]} Omitiendo la edición de SDDM 12H (se requiere contraseña de sudo)." 2>&1 | tee -a "$log"
      return
    fi
    sudo -n sed -i 's|^HourFormat="HH:mm"|## HourFormat="HH:mm"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log" || true
  fi
}

apply_sddm_12h_format_sequoia() {
  local sddm_directory="$1"
  local log="$2"
  if [ -d "$sddm_directory" ]; then
    echo "El tema ${YELLOW}sddm sequoia_2${RESET} existe. Editando al formato de 12H" 2>&1 | tee -a "$log"
    if ! sudo -n sed -i 's|^clockFormat="HH:mm"|## clockFormat="HH:mm"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log"; then
      echo "${WARN:-[WARN]} Omitiendo la edición de SDDM Sequoia 12H (se requiere contraseña de sudo)." 2>&1 | tee -a "$log"
      return
    fi
    if ! grep -q 'clockFormat="hh:mm AP"' "$sddm_directory/theme.conf"; then
      sudo -n sed -i '/^clockFormat=/a clockFormat="hh:mm AP"' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log" || true
    fi
    echo "${OK} Formato de 12H configurado en SDDM con éxito." 2>&1 | tee -a "$log"
  fi
}


# Express upgrade confirmation; may set EXPRESS_MODE=1.
prompt_express_upgrade() {
  local express_supported="$1"
  local log="$2"
  if [ "$EXPRESS_MODE" -eq 1 ] && [ "$express_supported" -eq 0 ]; then
    echo "${NOTE} El modo exprés requiere dotfiles instalados v${MIN_EXPRESS_VERSION} o más recientes. Continuando con las preguntas de actualización estándar." 2>&1 | tee -a "$log"
    EXPRESS_MODE=0
    return
  fi
  if [ "$UPGRADE_MODE" -eq 1 ] && [ "$EXPRESS_MODE" -eq 0 ]; then
    if [ "$express_supported" -eq 0 ]; then
      echo "${NOTE} El modo exprés requiere dotfiles instalados v${MIN_EXPRESS_VERSION} o más recientes. Continuando con las preguntas de actualización estándar." 2>&1 | tee -a "$log"
    else
      EXPRESS_MODE=1
      echo "${INFO} Modo exprés habilitado automáticamente para esta actualización." 2>&1 | tee -a "$log"
    fi
  fi
}
