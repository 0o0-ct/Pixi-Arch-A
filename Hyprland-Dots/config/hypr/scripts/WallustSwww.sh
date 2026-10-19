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

# Mean luminance of the top band of the wallpaper. That strip is what actually
# sits behind the top bar, so it — not the whole-image mean — decides which
# glass finish the bar wears: a dark photo with a bright sky owns the same
# problem as a fully bright one. Falls back to the whole image if the crop
# fails, and to an empty string (dark finish) when ImageMagick is missing.
detect_wallpaper_band_mean() {
  local img="$1"
  local band="" whole=""
  if command -v magick >/dev/null 2>&1; then
    band=$(magick "$img" -gravity north -crop 100%x7%+0+0 +repage -scale 1x1 -format '%[fx:mean]' info: 2>/dev/null || true)
    whole=$(magick "$img" -scale 1x1 -format '%[fx:mean]' info: 2>/dev/null || true)
  fi
  if [[ -n "$band" ]]; then printf '%s' "$band"; else printf '%s' "$whole"; fi
}

# Make sure the active stylesheet resolves wallust/mode-glass.css. Styles can
# ship the import themselves; for the rest it is injected right after the
# colors-waybar import line (never inside a comment that merely mentions it).
# The symlink is resolved first so the edit lands in the real stylesheet and
# waybar keeps loading the same file it was pointed at.
ensure_mode_glass_import() {
  local style_file="$HOME/.config/waybar/style.css"
  local style_target line
  [[ -f "$style_file" ]] || return 0
  style_target=$(readlink -f "$style_file" 2>/dev/null || printf '%s' "$style_file")
  [[ -f "$style_target" ]] || return 0
  grep -q "wallust/mode-glass.css" "$style_target" && return 0
  line=$(grep -nE '^[[:space:]]*@import[^;]*wallust/colors-waybar\.css' "$style_target" | head -1 | cut -d: -f1)
  [[ -n "$line" ]] || return 0
  {
    head -n "$line" "$style_target"
    printf '%s\n' '@import url("wallust/mode-glass.css");'
    tail -n +"$((line + 1))" "$style_target"
  } > "$style_target.tmp" 2>/dev/null && mv "$style_target.tmp" "$style_target" 2>/dev/null || true
}

# Rewrite the adaptive token set consumed by the glass waybar styles. Two
# hand-tuned finishes of the same material:
#   DARK band  -> smoked glass + light ink (the classic look, unchanged)
#   LIGHT band -> porcelain frosted glass + charcoal ink, so a bright can
#                 never swallow the bar again
# Lives in $HOME/.config/waybar/wallust/mode-glass.css and is rewritten on
# every wallpaper change; never edit that file by hand.
apply_dynamic_waybar_glass() {
  local band_mean="$1"
  local mode_css="$HOME/.config/waybar/wallust/mode-glass.css"
  mkdir -p "$(dirname "$mode_css")"
  ensure_mode_glass_import

  # 0.55 band brightness is the point where light ink starts drowning in the
  # wallpaper; everything brighter switches to porcelain + dark ink.
  if [[ -n "$band_mean" ]] && awk "BEGIN{exit !($band_mean >= 0.55)}"; then
    cat << 'EOF' > "$mode_css"
/* Dynamic adaptive mode: LIGHT wallpaper band (porcelain frosted glass) */
/* No drop shadow here: GTK compresses it into a dark crescent hugging the
 * island edge, which reads as a semi-black layer under the bar. The pane tint
 * plus the 14% ink hairline already define the islands on bright walls. */
@define-color pane_glass    alpha(@color15, 0.62);
@define-color edge_glass    rgba(46, 42, 47, 0.14);
@define-color shadow_glass  rgba(28, 22, 32, 0);

@define-color ink           #2E2A2F;
@define-color ink_muted     rgba(46, 42, 47, 0.78);
@define-color lift          rgba(46, 42, 47, 0.06);
@define-color lift_hi       rgba(46, 42, 47, 0.11);
@define-color edge          rgba(46, 42, 47, 0.10);
@define-color edge_hi       rgba(46, 42, 47, 0.20);
@define-color accent_ink    #552b50;
@define-color on_accent     #2E2A2F;
@define-color warn          #9a5b00;
@define-color danger        #b3261e;
EOF
  else
    cat << 'EOF' > "$mode_css"
/* Dynamic adaptive mode: DARK wallpaper band (translucent smoked glass) */
@define-color pane_glass    alpha(@color15, 0.11);
@define-color edge_glass    alpha(@color15, 0.47);
@define-color shadow_glass  rgba(0, 0, 0, 0.10);

@define-color ink           @foreground;
@define-color ink_muted     alpha(@foreground, 0.80);
@define-color lift          alpha(@foreground, 0.06);
@define-color lift_hi       alpha(@foreground, 0.13);
@define-color edge          alpha(@foreground, 0.10);
@define-color edge_hi       alpha(@foreground, 0.18);
@define-color accent_ink    @color15;
@define-color on_accent     #12141a;
@define-color warn          #ffb454;
@define-color danger        #ffa8a8;
EOF
  fi
}

# Same two finishes, for the Quickshell panels: Theme.qml watches this file
# and swaps the floating card to porcelain when the band is light. `base` is
# wallust color15 — the same key the waybar pane is tinted with — read from
# the freshly written palette so both surfaces share one material.
# Lives in $HOME/.config/quickshell/mode-glass.json; never edit it by hand.
apply_dynamic_quickshell_glass() {
  local band_mean="$1"
  local mode_json="$HOME/.config/quickshell/mode-glass.json"
  local palette_css="$HOME/.config/waybar/wallust/colors-waybar.css"
  local base=""
  base=$(sed -n 's/^@define-color[[:space:]]\+color15[[:space:]]\+\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$palette_css" 2>/dev/null | head -n 1 || true)
  [[ -n "$base" ]] || base="#EAE7EC"

  local branch="dark"
  if [[ -n "$band_mean" ]] && awk "BEGIN{exit !($band_mean >= 0.55)}"; then
    branch="light"
  fi

  mkdir -p "$(dirname "$mode_json")"
  cat << EOF > "$mode_json"
{
  "branch": "$branch",
  "base": "$base"
}
EOF
}

wallpaper_band_mean=$(detect_wallpaper_band_mean "$wallpaper_path")
apply_dynamic_waybar_glass "$wallpaper_band_mean"

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

# Quickshell glass branch from the same band measurement, now that the
# palette it reads color15 from is the live one.
apply_dynamic_quickshell_glass "$wallpaper_band_mean"

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
