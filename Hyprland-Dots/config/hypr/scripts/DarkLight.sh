#!/usr/bin/env bash
## /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Switch the wallpaper family and the Material 3 mode.
#
# Colour ownership lives in pixi_colors.py.  This script only picks a
# wallpaper, asks the engine for dark/light mode, and updates the Qt/GTK
# application themes.  It never edits generated palette files, never runs
# Wallust directly, and never kills Waybar/rofi/SwayNC/AGS/QuickShell.

set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

mode_arg="${1:-dark}"
case "$mode_arg" in
  dark|Dark) mode_arg="dark"; theme_marker="Dark" ;;
  light|Light) mode_arg="light"; theme_marker="Light" ;;
  auto|Auto) mode_arg="auto"; theme_marker="Auto" ;;
  *) printf 'Usage: %s [dark|light|auto]\n' "${0##*/}" >&2; exit 2 ;;
esac

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_base_path="$PICTURES_DIR/wallpapers/Dynamic-Wallpapers"
if [ ! -d "$wallpaper_base_path" ] && [ -d "$HOME/Imágenes/wallpapers/Dynamic-Wallpapers" ]; then
  wallpaper_base_path="$HOME/Imágenes/wallpapers/Dynamic-Wallpapers"
fi
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"

SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/swaync/images/bell.png"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"

# ---------------------------------------------------------------------------
# Pick the next wallpaper from the matching family.  If the family is empty,
# reuse the current wallpaper so mode/colour switching still works.
# ---------------------------------------------------------------------------
pick_random_wallpaper() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  find -L "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 2>/dev/null \
    | shuf -z -n 1 2>/dev/null \
    | tr -d '\0'
}

next_wallpaper=""
case "$mode_arg" in
  light) next_wallpaper="$(pick_random_wallpaper "$light_wallpapers")" ;;
  dark) next_wallpaper="$(pick_random_wallpaper "$dark_wallpapers")" ;;
  auto) next_wallpaper="$wallpaper_current" ;;
esac

if [ -z "$next_wallpaper" ] || [ ! -f "$next_wallpaper" ]; then
  if [ -f "$wallpaper_current" ]; then
    next_wallpaper="$wallpaper_current"
  elif [ -L "$HOME/.config/rofi/.current_wallpaper" ]; then
    next_wallpaper="$(readlink -f "$HOME/.config/rofi/.current_wallpaper")"
  else
    next_wallpaper="$(find -L "$PICTURES_DIR/wallpapers" "$HOME/Imágenes/wallpapers" \
      -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      2>/dev/null | shuf -n 1)"
  fi
fi

notify-send -u low -i "$notif" "Cambiando fondo de pantalla…" \
  "Generando colores ${theme_marker} Glass" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Apply the image with swww/awww, then let the single colour engine render.
# ---------------------------------------------------------------------------
if [ -n "$next_wallpaper" ] && [ -f "$next_wallpaper" ]; then
  if command -v swww >/dev/null 2>&1 || command -v awww >/dev/null 2>&1; then
    if command -v swww >/dev/null 2>&1; then
      wallpaper_cmd="swww"
    else
      wallpaper_cmd="awww"
    fi
    if ! "$wallpaper_cmd" query >/dev/null 2>&1; then
      if command -v awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
      elif command -v swww-daemon >/dev/null 2>&1; then
        swww-daemon >/dev/null 2>&1 &
      fi
      sleep 0.7
    fi
    "$wallpaper_cmd" img "$next_wallpaper" \
      --transition-bezier .43,1.19,1,.4 \
      --transition-fps 60 \
      --transition-type grow \
      --transition-pos 0.925,0.977 \
      --transition-duration 2 >/dev/null 2>&1 || true
  fi

  # The engine copies the image to .wallpaper_current, writes the rofi link,
  # renders every consumer and performs only targeted reloads.
  if ! "$SCRIPTSDIR/WallustSwww.sh" "$next_wallpaper" --mode "$mode_arg" --persist; then
    notify-send -u critical -i "$notif" "No se pudieron generar los colores" \
      "Revisa ~/.cache/pixi-colors/last-run.json" 2>/dev/null || true
    exit 1
  fi
else
  printf 'No wallpaper file found to apply.\n' >&2
  exit 1
fi

# The engine resolves "auto" from the image luminance.  Use that resolved mode
# for every non-generated application theme too, otherwise Qt and the GTK theme
# name would stay on the previous branch after an auto switch.
resolved_mode="dark"
if command -v jq >/dev/null 2>&1; then
  resolved_mode="$(jq -r '.mode // "dark"' "$HOME/.cache/pixi-colors/last-run.json" 2>/dev/null)"
fi
case "$resolved_mode" in
  light) theme_marker="Light" ;;
  *) resolved_mode="dark"; theme_marker="Dark" ;;
esac

if [ "$resolved_mode" = "light" ]; then
  qt5ct_color_scheme="$qt5ct_light"
  qt6ct_color_scheme="$qt6ct_light"
  kvantum_theme="catppuccin-latte-blue"
else
  qt5ct_color_scheme="$qt5ct_dark"
  qt6ct_color_scheme="$qt6ct_dark"
  kvantum_theme="catppuccin-mocha-blue"
fi

printf '%s\n' "$theme_marker" > "$HOME/.cache/.theme_mode"

# ---------------------------------------------------------------------------
# Qt / Kvantum.  These are application themes, not generated colour files;
# the engine already owns GTK's gtk.css and the desktop color-scheme.
# ---------------------------------------------------------------------------
if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ] && [ -n "$qt5ct_color_scheme" ]; then
  sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" \
    "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null || true
fi
if [ -f "$HOME/.config/qt6ct/qt6ct.conf" ] && [ -n "$qt6ct_color_scheme" ]; then
  sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" \
    "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null || true
fi
if command -v kvantummanager >/dev/null 2>&1; then
  kvantummanager --set "$kvantum_theme" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# GTK theme / icon family.  This is intentionally separate from generated
# colours: the engine controls gtk.css and the M3 palette, while this chooses
# the matching shell theme and icon set.
# ---------------------------------------------------------------------------
set_custom_gtk_theme() {
  local mode="$1"
  local color_setting="org.gnome.desktop.interface color-scheme"
  local theme_setting="org.gnome.desktop.interface gtk-theme"
  local icon_setting="org.gnome.desktop.interface icon-theme"
  local settings_file="$HOME/.config/gtk-3.0/settings.ini"
  local settings_file_4="$HOME/.config/gtk-4.0/settings.ini"
  local current_theme="" current_icon="" new_theme new_icon

  command -v gsettings >/dev/null 2>&1 || return 0

  if [ -f "$settings_file" ]; then
    current_theme=$(grep -E '^\s*gtk-theme-name\s*=' "$settings_file" | cut -d'=' -f2 | tr -d "'\" ")
    current_icon=$(grep -E '^\s*gtk-icon-theme-name\s*=' "$settings_file" | cut -d'=' -f2 | tr -d "'\" ")
  fi
  [ -n "$current_theme" ] || current_theme=$(gsettings get "$theme_setting" 2>/dev/null | tr -d "'")
  [ -n "$current_icon" ] || current_icon=$(gsettings get "$icon_setting" 2>/dev/null | tr -d "'")

  if [ "$mode" = "Light" ]; then
    gsettings set "$color_setting" 'prefer-light' 2>/dev/null || true
    new_theme="${current_theme/Dark/Light}"; new_theme="${new_theme/dark/light}"
    new_icon="${current_icon/Dark/Light}"; new_icon="${new_icon/dark/light}"
  else
    gsettings set "$color_setting" 'prefer-dark' 2>/dev/null || true
    new_theme="${current_theme/Light/Dark}"; new_theme="${new_theme/light/dark}"
    new_icon="${current_icon/Light/Dark}"; new_icon="${new_icon/light/dark}"
  fi

  if [ ! -d "$HOME/.themes/$new_theme" ] && [ ! -d "/usr/share/themes/$new_theme" ]; then
    local themes=() theme_search
    while IFS= read -r -d '' theme_search; do
      themes+=("$(basename "$theme_search")")
    done < <(find "$HOME/.themes" -maxdepth 1 -type d -iname "*${mode}*" -print0 2>/dev/null)
    if [ ${#themes[@]} -gt 0 ]; then
      new_theme=${themes[RANDOM % ${#themes[@]}]}
    else
      new_theme="$current_theme"
    fi
  fi

  if [ ! -d "$HOME/.icons/$new_icon" ] && [ ! -d "/usr/share/icons/$new_icon" ]; then
    local icons=() icon_search
    while IFS= read -r -d '' icon_search; do
      icons+=("$(basename "$icon_search")")
    done < <(find "$HOME/.icons" -maxdepth 1 -type d -iname "*${mode}*" -print0 2>/dev/null)
    if [ ${#icons[@]} -gt 0 ]; then
      new_icon=${icons[RANDOM % ${#icons[@]}]}
    else
      new_icon="$current_icon"
    fi
  fi

  gsettings set "$theme_setting" "$new_theme" 2>/dev/null || true
  if [ -f "$settings_file" ]; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$new_theme|" "$settings_file" 2>/dev/null || true
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$new_icon|" "$settings_file" 2>/dev/null || true
  fi
  if [ -f "$settings_file_4" ]; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$new_theme|" "$settings_file_4" 2>/dev/null || true
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$new_icon|" "$settings_file_4" 2>/dev/null || true
  fi
  gsettings set "$icon_setting" "$new_icon" 2>/dev/null || true

  if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ]; then
    sed -i "s|^icon_theme=.*$|icon_theme=$new_icon|" "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null || true
  fi
  if [ -f "$HOME/.config/qt6ct/qt6ct.conf" ]; then
    sed -i "s|^icon_theme=.*$|icon_theme=$new_icon|" "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null || true
  fi

  if command -v flatpak >/dev/null 2>&1; then
    flatpak --user override --filesystem="$HOME/.themes" >/dev/null 2>&1 || true
    flatpak --user override --env=GTK_THEME="$new_theme" >/dev/null 2>&1 || true
    flatpak --user override --filesystem="$HOME/.icons" >/dev/null 2>&1 || true
    flatpak --user override --env=ICON_THEME="$new_icon" >/dev/null 2>&1 || true
  fi
}

set_custom_gtk_theme "$theme_marker"

notify-send -u low -i "$notif" "Fondo y colores ${theme_marker}:" \
  "Regenerados con éxito" 2>/dev/null || true

exit 0
