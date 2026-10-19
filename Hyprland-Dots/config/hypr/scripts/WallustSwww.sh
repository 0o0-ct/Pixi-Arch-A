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

# Same two finishes, for rofi: the Frosted base theme and the wallpaper
# selector consume these tokens instead of hardcoded whites, so a bright
# wallpaper can never wash the menus out either. Concrete rgba() values
# because rasi cannot compose alpha() over variables. Lives in
# $HOME/.config/rofi/wallust/mode-glass.rasi; never edit that file by hand.
apply_dynamic_rofi_glass() {
  local band_mean="$1"
  local mode_rasi="$HOME/.config/rofi/wallust/mode-glass.rasi"
  local palette_css="$HOME/.config/waybar/wallust/colors-waybar.css"
  local base=""
  base=$(sed -n 's/^@define-color[[:space:]]\+color15[[:space:]]\+\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$palette_css" 2>/dev/null | head -n 1 || true)
  [[ -n "$base" ]] || base="#EAE7EC"

  # color15 -> r,g,b for the porcelain pane
  local pr=234 pg=231 pb=236
  if [[ "$base" =~ ^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$ ]]; then
    pr=$((16#${BASH_REMATCH[1]})); pg=$((16#${BASH_REMATCH[2]})); pb=$((16#${BASH_REMATCH[3]}))
  fi

  mkdir -p "$(dirname "$mode_rasi")"

  if [[ -n "$band_mean" ]] && awk "BEGIN{exit !($band_mean >= 0.55)}"; then
    cat << EOF > "$mode_rasi"
/* Dynamic adaptive mode: LIGHT wallpaper band (porcelain frosted glass). */
/* The window is the same pane the waybar uses: color15 at 62%. */
* {
    pane:           rgba($pr, $pg, $pb, 0.62);
    pane-soft:      rgba(46, 42, 47, 0.03);
    element-bg:     rgba(46, 42, 47, 0.04);
    element-edge:   rgba(46, 42, 47, 0.08);
    lift:           rgba(46, 42, 47, 0.06);
    lift-hi:        rgba(46, 42, 47, 0.10);
    edge:           rgba(46, 42, 47, 0.12);
    edge-soft:      rgba(46, 42, 47, 0.14);
    edge-hi:        rgba(46, 42, 47, 0.20);
    edge-strong:    rgba(46, 42, 47, 0.26);
    selected-edge:  rgba(46, 42, 47, 0.30);
    edge-glass:     rgba(46, 42, 47, 0.14);
    ink:            #2E2A2F;
    placeholder:    rgba(46, 42, 47, 0.55);
}
EOF
  else
    cat << 'EOF' > "$mode_rasi"
/* Dynamic adaptive mode: DARK wallpaper band (smoked glass + light ink). */
* {
    pane:           rgba(255, 255, 255, 0.11);
    pane-soft:      rgba(255, 255, 255, 0.03);
    element-bg:     rgba(255, 255, 255, 0.04);
    element-edge:   rgba(255, 255, 255, 0.08);
    lift:           rgba(255, 255, 255, 0.06);
    lift-hi:        rgba(255, 255, 255, 0.08);
    edge:           rgba(255, 255, 255, 0.12);
    edge-soft:      rgba(255, 255, 255, 0.15);
    edge-hi:        rgba(255, 255, 255, 0.22);
    edge-strong:    rgba(255, 255, 255, 0.35);
    selected-edge:  rgba(255, 255, 255, 0.45);
    edge-glass:     rgba(255, 255, 255, 0.47);
    ink:            @foreground;
    placeholder:    rgba(255, 255, 255, 0.45);
}
EOF
  fi
}

# Echoes the given wallust-hyprland.conf accent as rgb(rrggbb), mixed 25%
# toward the porcelain ink. Falls back to the live variable reference when
# the palette line is missing.
palette_ink_mix() {
  local pal="$1" name="$2"
  local hex=""
  hex=$(sed -n "s/^\$${name}[[:space:]]*=[[:space:]]*rgb(\([0-9a-fA-F]\{6\}\)).*/\1/p" "$pal" 2>/dev/null | head -n 1 || true)
  if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
    printf '$%s' "$name"
    return
  fi
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  r=$(( (r * 3 + 46) / 4 )); g=$(( (g * 3 + 42) / 4 )); b=$(( (b * 3 + 47) / 4 ))
  printf 'rgb(%02x%02x%02x)' "$r" "$g" "$b"
}

# Lock screen: the same two finishes. hyprlock.conf sources the generated
# file right after the wallust palette, and its inline values double as
# the dark fallbacks. Dark side: the accent variables are re-emitted
# untouched. Porcelain: the accents that act as text mix toward the ink,
# and the cards take the same color15 pane as the bar and the menus.
apply_dynamic_hyprlock_glass() {
  local band_mean="$1"
  local mode_conf="$HOME/.config/hypr/wallust/mode-glass-lock.conf"
  local palette_css="$HOME/.config/waybar/wallust/colors-waybar.css"
  local hypr_palette="$HOME/.config/hypr/wallust/wallust-hyprland.conf"
  local base=""
  base=$(sed -n 's/^@define-color[[:space:]]\+color15[[:space:]]\+\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$palette_css" 2>/dev/null | head -n 1 || true)
  [[ -n "$base" ]] || base="#EAE7EC"

  local pr=234 pg=231 pb=236
  if [[ "$base" =~ ^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$ ]]; then
    pr=$((16#${BASH_REMATCH[1]})); pg=$((16#${BASH_REMATCH[2]})); pb=$((16#${BASH_REMATCH[3]}))
  fi

  mkdir -p "$(dirname "$mode_conf")"

  if [[ -n "$band_mean" ]] && awk "BEGIN{exit !($band_mean >= 0.55)}"; then
    cat << EOF > "$mode_conf"
# Dynamic adaptive mode: LIGHT wallpaper band (porcelain lock screen).
\$lock_date = rgba(46, 42, 47, 0.9)
\$lock_time = rgba(46, 42, 47, 0.95)
\$lock_user = $(palette_ink_mix "$hypr_palette" color9)
\$lock_layout = $(palette_ink_mix "$hypr_palette" color8)
\$lock_field_border = $(palette_ink_mix "$hypr_palette" color8)
\$lock_field_bg = rgba($pr, $pg, $pb, 0.62)
\$lock_field_text = $(palette_ink_mix "$hypr_palette" color13)
\$lock_capslock = rgb(46, 42, 47)
\$lock_placeholder = ##2e2a2f99
\$lock_card_bg = rgba($pr, $pg, $pb, 0.62)
\$lock_card_border = rgba(46, 42, 47, 0.14)
\$lock_card_text = rgba(46, 42, 47, 0.8)
EOF
  else
    cat << 'EOF' > "$mode_conf"
# Dynamic adaptive mode: DARK wallpaper band (classic white glass).
$lock_date = rgba(255, 255, 255, 0.9)
$lock_time = rgba(255, 255, 255, 0.95)
$lock_user = $color9
$lock_layout = $color8
$lock_field_border = $color8
$lock_field_bg = rgba(255, 255, 255, 0.1)
$lock_field_text = $color13
$lock_capslock = rgb(255, 255, 255)
$lock_placeholder = ##ffffff99
$lock_card_bg = rgba(15, 20, 30, 0.45)
$lock_card_border = rgba(255, 255, 255, 0.15)
$lock_card_text = rgba(255, 255, 255, 0.8)
EOF
  fi
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

# Quickshell, rofi and hyprlock glass branches from the same band
# measurement, now that the palette they read color15 from is the live one.
apply_dynamic_quickshell_glass "$wallpaper_band_mean"
apply_dynamic_rofi_glass "$wallpaper_band_mean"
apply_dynamic_hyprlock_glass "$wallpaper_band_mean"

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
