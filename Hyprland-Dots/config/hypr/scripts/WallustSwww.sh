#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Wallust: derive colors from the current wallpaper and update templates
# Usage: WallustSwww.sh [absolute_path_to_wallpaper]

# Add local bin to PATH for swww/awww compatibility
export PATH="$HOME/.local/bin:$PATH"

set -euo pipefail

# Inputs and paths
passed_path="${1:-}"
cache_dir="$HOME/.cache/swww/"
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
read_cached_wallpaper() {
  local cache_file="$1"
  if [[ -f "$cache_file" ]]; then
    awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
  fi
}

read_wallpaper_from_query() {
  local monitor="$1"
  swww query | awk -v mon="$monitor" '
    $0 ~ mon && /image:/ {
      sub(/^.*image: /,"")
      print
      exit
    }
  '
}

# Helper: get focused monitor name (prefer JSON)
get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

# Determine wallpaper_path
wallpaper_path=""
if [[ -n "$passed_path" && -f "$passed_path" ]]; then
  wallpaper_path="$passed_path"
else
  # Try to read from swww cache for the focused monitor, with a short retry loop
  current_monitor="$(get_focused_monitor)"
  cache_file="$cache_dir$current_monitor"

  # Wait briefly for swww to write its cache after an image change
  for i in {1..10}; do
    if [[ -f "$cache_file" ]]; then
      break
    fi
    sleep 0.1
  done

  if [[ -f "$cache_file" ]]; then
    # The first non-filter line is the original wallpaper path
    wallpaper_path="$(read_cached_wallpaper "$cache_file")"
  fi

  if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(read_wallpaper_from_query "$current_monitor")"
  fi
fi

if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  exit 0
fi

detect_wallpaper_mean() {
  local img="$1"
  if command -v magick >/dev/null 2>&1; then
    magick "$img" -scale 1x1 -format '%[fx:mean]' info: 2>/dev/null || true
  fi
}

apply_dynamic_waybar_glass() {
  local mean="$1"
  local mode_css="$HOME/.config/waybar/wallust/mode-glass.css"
  local style_file="$HOME/.config/waybar/style.css"
  mkdir -p "$(dirname "$mode_css")"

  # Ensure style.css imports mode-glass.css
  if [[ -f "$style_file" ]] && ! grep -q "wallust/mode-glass.css" "$style_file"; then
    sed -i '/wallust\/colors-waybar.css/a @import url("wallust/mode-glass.css");' "$style_file" 2>/dev/null || true
  fi

  if [[ -n "$mean" ]] && awk "BEGIN{exit !($mean > 0.58)}"; then
    # Light wallpaper -> Soft Frosted White Glass + Deep Charcoal Typography (no harsh OLED black bars)
    cat << 'EOF' > "$mode_css"
/* Dynamic adaptive mode: LIGHT wallpaper (frosted white glass) */
@define-color pane_glass    rgba(255, 255, 255, 0.45);
@define-color edge_glass    rgba(255, 255, 255, 0.75);
@define-color shadow_glass  rgba(0, 0, 0, 0.06);

@define-color ink           #2E2A2F;
@define-color ink_dim       rgba(46, 42, 47, 0.75);
@define-color tile          rgba(0, 0, 0, 0.04);
@define-color tile_hi       rgba(0, 0, 0, 0.08);
@define-color edge          rgba(0, 0, 0, 0.08);
@define-color edge_top      rgba(255, 255, 255, 0.85);
@define-color on_accent     #ffffff;
EOF
  else
    # Dark wallpaper -> Translucent Dark Glass + Light Foreground
    cat << 'EOF' > "$mode_css"
/* Dynamic adaptive mode: DARK wallpaper (translucent dark glass) */
@define-color pane_glass    alpha(@color15, 0.11);
@define-color edge_glass    alpha(@color15, 0.47);
@define-color shadow_glass  rgba(0, 0, 0, 0.10);

@define-color ink           @foreground;
@define-color ink_dim       alpha(@foreground, 0.80);
@define-color tile          alpha(@foreground, 0.05);
@define-color tile_hi       alpha(@foreground, 0.13);
@define-color edge          alpha(@color14, 0.30);
@define-color edge_top      alpha(@color15, 0.75);
@define-color on_accent     #12141a;
EOF
  fi
}

wallpaper_mean=$(detect_wallpaper_mean "$wallpaper_path")
apply_dynamic_waybar_glass "$wallpaper_mean"

ln -sf "$wallpaper_path" "$rofi_link" || true
mkdir -p "$(dirname "$wallpaper_current")"
cp -f "$wallpaper_path" "$wallpaper_current" || true

# Ensure Ghostty directory exists so Wallust can write target even if Ghostty isn't installed
mkdir -p "$HOME/.config/ghostty" || true
wait_for_templates() {
  local start_ts="$1"
  shift
  local files=("$@")
  for _ in {1..50}; do
    local ready=true
    for file in "${files[@]}"; do
      if [[ ! -s "$file" ]]; then
        ready=false
        break
      fi
      local mtime
      mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
      if (( mtime < start_ts )); then
        ready=false
        break
      fi
    done
    $ready && return 0
    sleep 0.1
  done
  return 1
}

# Run wallust (silent) as base palette
start_ts=$(date +%s)
wallust run -s "$wallpaper_path" || true

# Run Matugen (Material Design 3 / Monet extraction from ~/JaKooLit/extraccion de colores)
if command -v matugen >/dev/null 2>&1; then
  matugen image "$wallpaper_path" --source-color-index 0 || true
fi

wallust_targets=(
  "$HOME/.config/waybar/wallust/colors-waybar.css"
  "$HOME/.config/rofi/wallust/colors-rofi.rasi"
  "$HOME/.config/quickshell/qml_color.json"
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk.css"
)
wait_for_templates "$start_ts" "${wallust_targets[@]}" || true


# Normalize Ghostty palette syntax in case ':' was used by older files
if [ -f "$HOME/.config/ghostty/wallust.conf" ]; then
  sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$HOME/.config/ghostty/wallust.conf" 2>/dev/null || true
fi

# Light wait for Ghostty colors file to be present then signal Ghostty to reload (SIGUSR2)
for _ in 1 2 3; do
  [ -s "$HOME/.config/ghostty/wallust.conf" ] && break
  sleep 0.1
done
if pidof ghostty >/dev/null; then
  for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
fi

# Reload Hyprland borders with newly generated M3 colors
hyprctl reload >/dev/null 2>&1 || true

# Signal Kitty to reload colors
if pidof kitty >/dev/null 2>&1; then
  pkill -SIGUSR1 kitty 2>/dev/null || true
fi

# Reload SwayNC CSS if swaync is actually running
if pidof swaync >/dev/null 2>&1 && command -v swaync-client >/dev/null 2>&1; then
  swaync-client -R -rs >/dev/null 2>&1 || true
fi

# Prompt Waybar to reload colours.
# SIGUSR2 does NOT reload the stylesheet on Waybar 0.15.0, and `waybar-msg` is
# not installed here, so the previous code changed nothing and the bar kept the
# OLD palette in memory after every wallpaper change. Only a real restart
# re-reads the CSS (and therefore re-resolves the wallust @import).
if pidof waybar >/dev/null 2>&1; then
  pkill -x waybar 2>/dev/null || true
  sleep 0.3
  hyprctl dispatch exec waybar >/dev/null 2>&1 || true
fi

# Automatically sync SDDM wallpaper with the new desktop wallpaper
if [ -f "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" ]; then
  "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" --normal >/dev/null 2>&1 &
fi

# Update Papirus folder color cleanly when wallpaper changes
if [ -f "$HOME/.config/hypr/scripts/SetFolderColor.sh" ]; then
  "$HOME/.config/hypr/scripts/SetFolderColor.sh" >/dev/null 2>&1 &
fi
