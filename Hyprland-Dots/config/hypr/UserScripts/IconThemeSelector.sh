#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Selector de Temas de Iconos con Rofi

rofi_theme="$HOME/.config/rofi/config-submenus.rasi"
[ ! -f "$rofi_theme" ] && rofi_theme="$HOME/.config/rofi/config.rasi"

# Directorios de iconos
icon_dirs=(
  "$HOME/.local/share/icons"
  "$HOME/.icons"
  "/usr/share/icons"
)

# Obtener tema actual
current_theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" | tr -d '"')"
[ -z "$current_theme" ] && current_theme="MacTahoe-dark"

# Recolectar temas válidos (con index.theme y sin ser solo cursores)
declare -A seen_themes
theme_list=()

for dir in "${icon_dirs[@]}"; do
  [ ! -d "$dir" ] && continue
  for t in "$dir"/*; do
    [ ! -d "$t" ] && continue
    bname=$(basename "$t")
    
    # Omitir duplicados o directorios especiales
    [[ -n "${seen_themes[$bname]}" ]] && continue
    [[ "$bname" =~ ^(default|hicolor|locolor|breeze_cursors|Bibata.*|macOS|macOS-White)$ ]] && continue
    
    # Verificar que tenga index.theme y no sea solo tema de cursor
    if [ -f "$t/index.theme" ]; then
      if grep -q "Directories=" "$t/index.theme" 2>/dev/null; then
        seen_themes["$bname"]=1
        theme_list+=("$bname")
      fi
    fi
  done
done

# Ordenar temas alfabéticamente
readarray -t sorted_themes < <(printf '%s\n' "${theme_list[@]}" | sort -V)

# Construir opciones para Rofi
rofi_input=""
for theme in "${sorted_themes[@]}"; do
  prefix="  "
  if [ "$theme" = "$current_theme" ]; then
    prefix="⭐ "
  fi
  # Buscar un icono representativo
  icon_path=""
  for idir in "${icon_dirs[@]}"; do
    if [ -f "$idir/$theme/scalable/apps/system-file-manager.svg" ]; then
      icon_path="$idir/$theme/scalable/apps/system-file-manager.svg"
      break
    elif [ -f "$idir/$theme/48x48/apps/system-file-manager.png" ]; then
      icon_path="$idir/$theme/48x48/apps/system-file-manager.png"
      break
    elif [ -f "$idir/$theme/32/apps/system-file-manager.svg" ]; then
      icon_path="$idir/$theme/32/apps/system-file-manager.svg"
      break
    fi
  done
  [ -z "$icon_path" ] && icon_path="preferences-desktop-theme"
  
  rofi_input+="${prefix}${theme}\x00icon\x1f${icon_path}\n"
done

# Mostrar en Rofi
chosen=$(printf "%b" "$rofi_input" | rofi -i -dmenu -config "$rofi_theme" -p "🎨 Selector de Iconos")

if [ -z "$chosen" ]; then
  exit 0
fi

# Limpiar selección
clean_theme=$(echo "$chosen" | sed 's/^[⭐ ]*//' | xargs)

# Aplicar el tema seleccionado
if [ -n "$clean_theme" ]; then
  # 1. GSettings (GNOME / GTK general)
  gsettings set org.gnome.desktop.interface icon-theme "$clean_theme" 2>/dev/null || true
  
  # 2. GTK 3
  if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$clean_theme|" "$HOME/.config/gtk-3.0/settings.ini"
  fi
  
  # 3. GTK 4
  if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$clean_theme|" "$HOME/.config/gtk-4.0/settings.ini"
  fi
  
  # 4. XSettingsd
  if [ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ]; then
    sed -i "s|^Net/IconThemeName \".*\"|Net/IconThemeName \"$clean_theme\"|" "$HOME/.config/xsettingsd/xsettingsd.conf"
    killall -HUP xsettingsd 2>/dev/null || true
  fi
  
  # 5. Notificación
  notify-send -i "preferences-desktop-theme" "Tema de Iconos Actualizado" "Activo: $clean_theme"
  
  # 6. Refrescar paneles si existe Refresh.sh
  if [ -x "$HOME/.config/hypr/scripts/Refresh.sh" ]; then
    "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 || true
  fi
fi
