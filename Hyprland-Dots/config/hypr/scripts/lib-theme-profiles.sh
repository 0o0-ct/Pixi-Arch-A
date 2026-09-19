#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
#
# lib-theme-profiles.sh
#   Shared helpers for ThemeProfileSave.sh and ThemeProfileRestore.sh.
#   This file is *sourced*, it is never executed directly.
#
# What a "theme profile" is
#   A self-contained snapshot of everything that defines how the desktop looks
#   right now, so that a global theme switch (Super+T -> ThemeChanger.sh) or a
#   rofi theme pick (RofiThemeSelector.sh) is never a one-way door.
#
#   The profile does NOT live inside any of the files it protects, and it does
#   not read them back at restore time (except for the rofi config, which is
#   restored surgically and falls back to its own stored copy). Deleting
#   ~/.config/rofi/config.rasi, ~/.config/waybar/config, ~/.config/waybar/style.css
#   or every wallust colour file still leaves a fully restorable profile.
#
# Layout of a profile (~/.config/theme-profiles/<name>/):
#   manifest        TSV header (name, created, host, rofi theme, ...) + one
#                   "entry" line per captured path, with sha256 of the payload.
#   files/<...>     the payload. Payload paths mirror the absolute origin path
#                   with the leading "/" stripped, e.g.
#                   files/home/$USER/.config/waybar/config
#
# Entry kinds
#   file      the live path was a regular file (or did not exist: "missing")
#   symlink   the live path was a symlink; link_raw is the untouched readlink(1)
#             value, so relative links survive, and the resolved target's
#             content is stored too whenever the target lives under ~/.config
#             (see TP_COPY_EXTERNAL_TARGETS). Targets outside ~/.config -- e.g.
#             a wallpaper in ~/Imágenes -- are referenced, never duplicated.
#   missing   the live path did not exist when the profile was saved; recorded
#             for the record, never resurrected and never deleted.

# shellcheck disable=SC2034

TP_VERSION="2"
TP_ROOT="${THEME_PROFILES_DIR:-$HOME/.config/theme-profiles}"
TP_LKG_NAME="last-known-good"

# Packaged colour files that wallust rewrites. This is exactly the set
# ThemeChanger.sh waits on plus the extra targets declared in wallust.toml, so
# a restore reproduces the same palette in every app the switcher touches.
# Every generated palette file declared in ~/.config/wallust/wallust.toml and
# ~/.config/matugen/config.toml. ThemeChanger.sh waits on the first five; the
# rest were a real gap -- a Gruvbox switch left cava, ags, swaync and GTK tinted
# with the old-vs-new palette while waybar/rofi looked restored.
TP_COLOR_TARGETS=(
  "$HOME/.config/waybar/wallust/colors-waybar.css"
  "$HOME/.config/rofi/wallust/colors-rofi.rasi"
  "$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
  "$HOME/.config/hypr/wallust/wallust-hyprland.conf"
  "$HOME/.config/ghostty/wallust.conf"
  "$HOME/.config/cava/config"
  "$HOME/.config/ags/style/abstracts/_variables.scss"
  "$HOME/.config/swaync/wallust/colors-wallust.css"
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk.css"
)

# The "who am I" paths: which rofi theme, which waybar config + style, which
# wallpaper. These are what a theme switch destroys and what a user notices.
TP_IDENTITY_PATHS=(
  "$HOME/.config/rofi/config.rasi"
  "$HOME/.config/waybar/config"
  "$HOME/.config/waybar/style.css"
  "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
  "$HOME/.config/rofi/.current_wallpaper"
)

# Opt-in: the wallust target inside ~/.config/quickshell. Off by default so the
# default entry set touches nothing under the quickshell config tree.
TP_OPT_QUICKSHELL_TARGET="$HOME/.config/quickshell/qml_color.json"

# The identity paths that are not plain colour files.
TP_ROFI_CONFIG="$HOME/.config/rofi/config.rasi"
TP_WAYBAR_CONFIG="$HOME/.config/waybar/config"
TP_WAYBAR_STYLE="$HOME/.config/waybar/style.css"
TP_WALLPAPER_COPY="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
TP_WALLPAPER_LINK="$HOME/.config/rofi/.current_wallpaper"

# Never duplicate the user's own media library into a profile.
TP_COPY_EXTERNAL_TARGETS="${TP_COPY_EXTERNAL_TARGETS:-0}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
tp_info() { printf '%s\n' "$*"; }
tp_warn() { printf 'aviso: %s\n' "$*" >&2; }
tp_err() { printf 'error: %s\n' "$*" >&2; }
tp_die() {
  tp_err "$*"
  exit 1
}

tp_have() { command -v "$1" >/dev/null 2>&1; }

tp_notify() {
  # tp_notify <urgency> <title> <body>
  [ "${TP_QUIET:-0}" = "1" ] && return 0
  tp_have notify-send || return 0
  notify-send -u "$1" -a ThemeProfile -h string:x-dunst-stack-tag:themeprofile "$2" "$3" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Profile naming / discovery
# ---------------------------------------------------------------------------
tp_valid_name() {
  # Reject anything that could escape the profile root or confuse the shell.
  local n="$1"
  [ -n "$n" ] || return 1
  case "$n" in
  . | .. | */* | *' '* | *$'\t'* | *$'\n'*) return 1 ;;
  esac
  [[ "$n" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  return 0
}

tp_default_name() { date +%Y-%m-%d_%H%M%S; }

tp_profile_dir() { printf '%s/%s\n' "$TP_ROOT" "$1"; }

tp_list_profiles() {
  [ -d "$TP_ROOT" ] || return 0
  local d
  for d in "$TP_ROOT"/*/; do
    [ -f "${d}manifest" ] || continue
    basename "${d%/}"
  done | sort
}

tp_human_size() {
  local p="$1" b
  [ -e "$p" ] || {
    printf '?'
    return
  }
  b=$(du -sb "$p" 2>/dev/null | cut -f1)
  if [ "${b:-0}" -ge 1048576 ]; then
    awk -v b="$b" 'BEGIN{printf "%.1fM", b/1048576}'
  elif [ "${b:-0}" -ge 1024 ]; then
    awk -v b="$b" 'BEGIN{printf "%.0fK", b/1024}'
  else
    printf '%sB' "${b:-0}"
  fi
}

# ---------------------------------------------------------------------------
# Path <-> payload mapping
# ---------------------------------------------------------------------------
tp_relpath_of() {
  # Absolute live path -> payload path relative to <profile>/files
  local abs="$1"
  printf 'files/%s\n' "${abs#/}"
}

tp_payload_of() {
  # <profile dir> <absolute live path> -> absolute payload path
  printf '%s/%s\n' "$1" "$(tp_relpath_of "$2")"
}

tp_sha256() {
  [ -f "$1" ] || {
    printf -- '-'
    return
  }
  sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

# ---------------------------------------------------------------------------
# Entry collection
# ---------------------------------------------------------------------------
tp_entry_paths() {
  # Emits "category<TAB>live_path" for everything that makes up the theme
  # identity, in a stable order. Category is "identity" or "colors".
  local with_qs="${1:-0}" p
  for p in "${TP_IDENTITY_PATHS[@]}"; do printf 'identity\t%s\n' "$p"; done
  for p in "${TP_COLOR_TARGETS[@]}"; do printf 'colors\t%s\n' "$p"; done
  [ "$with_qs" = "1" ] && printf 'colors\t%s\n' "$TP_OPT_QUICKSHELL_TARGET"
  return 0
}

tp_current_rofi_theme() {
  # Last effective @theme value in config.rasi, or empty.
  [ -f "$TP_ROFI_CONFIG" ] || return 0
  grep -oP '^\s*@theme\s+"\K[^"]+' "$TP_ROFI_CONFIG" 2>/dev/null | tail -n1
}

tp_first_wallpaper_source() {
  # The original (non-copied) wallpaper image, via the rofi symlink.
  if [ -L "$TP_WALLPAPER_LINK" ]; then
    readlink "$TP_WALLPAPER_LINK"
  fi
}

# tp_capture_entry <profile_dir> <live_path> <also_copy>
#   Appends one "entry" TSV line to <profile_dir>/manifest and copies the payload.
tp_capture_entry() {
  local pdir="$1" live="$2" category="${3:-identity}" also_copy="${4:-1}"
  local kind link_raw target rel payload sha note=""

  rel="$(tp_relpath_of "$live")"
  payload="$pdir/$rel"

  if [ -L "$live" ]; then
    kind="symlink"
    link_raw="$(readlink "$live")"
    target="$(readlink -f "$live" 2>/dev/null || true)"
    if [ -n "$target" ] && [ -f "$target" ]; then
      # Copy the resolved content when it is ours to protect (~/.config) or when
      # explicitly allowed; never duplicate the user's external media.
      if [ "$also_copy" = "1" ] &&
        { [ "$TP_COPY_EXTERNAL_TARGETS" = "1" ] || [[ "$target" == "$HOME/.config/"* ]]; }; then
        mkdir -p "$(dirname "$payload")"
        cp -Lf -- "$target" "$payload" || {
          tp_warn "no se pudo copiar el destino de $live"
          return 1
        }
        sha="$(tp_sha256 "$payload")"
        note="resolved_target=$target"
      else
        sha="-"
        note="external_target=$target"
      fi
    else
      sha="-"
      note="dangling_target=${target:-none}"
    fi
  elif [ -f "$live" ]; then
    kind="file"
    mkdir -p "$(dirname "$payload")"
    cp -Lf -- "$live" "$payload" || {
      tp_warn "no se pudo copiar $live"
      return 1
    }
    sha="$(tp_sha256 "$payload")"
    link_raw="-"
  elif [ -e "$live" ]; then
    kind="other"
    sha="-"
    link_raw="-"
    note="not_a_regular_file_or_symlink"
  else
    kind="missing"
    sha="-"
    link_raw="-"
    note="absent_when_saved"
  fi

  local size="-"
  [ -f "$payload" ] && size="$(stat -c %s "$payload" 2>/dev/null || echo '-')"

  printf 'entry\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$category" "$kind" "$live" "$rel" "${link_raw:--}" "${target:--}" "$sha" "$size" "$note" \
    >>"$pdir/manifest"
  return 0
}

# ---------------------------------------------------------------------------
# Manifest writing
# ---------------------------------------------------------------------------
tp_manifest_header() {
  # tp_manifest_header <profile_dir> <name> <tag> <with_qs>
  local pdir="$1" name="$2" tag="$3" with_qs="$4"
  local rofi_theme wall_src
  rofi_theme="$(tp_current_rofi_theme)"
  wall_src="$(tp_first_wallpaper_source)"

  {
    printf '# theme-profile v%s -- self-contained snapshot of the desktop theme identity\n' "$TP_VERSION"
    printf '# Regenerate a profile with: %s/ThemeProfileSave.sh <nombre>\n' "$HOME/.config/hypr/scripts"
    printf '# Restore a profile with:    %s/ThemeProfileRestore.sh <nombre>\n' "$HOME/.config/hypr/scripts"
    printf 'format\t%s\n' "$TP_VERSION"
    printf 'name\t%s\n' "$name"
    printf 'created\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S%:z)"
    printf 'created_human\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'host\t%s\n' "$(uname -n 2>/dev/null || cat /etc/hostname 2>/dev/null || echo desconocido)"
    printf 'user\t%s\n' "$(id -un)"
    printf 'home\t%s\n' "$HOME"
    printf 'tag\t%s\n' "${tag:--}"
    printf 'rofi_theme\t%s\n' "${rofi_theme:--}"
    printf 'wallpaper_source\t%s\n' "${wall_src:--}"
    printf 'quickshell_included\t%s\n' "$with_qs"
    printf 'hyprland\t%s\n' "$(hyprctl version 2>/dev/null | head -n1 | sed 's/ built from.*//' || echo desconocido)"
    printf 'waybar\t%s\n' "$(waybar --version 2>/dev/null | head -n1 || echo desconocido)"
    printf 'generator\tThemeProfileSave.sh\n'
    printf '#\n'
    printf '# columns: entry  category  kind  live_path  payload_relpath  link_raw  resolved_target  sha256  bytes  note\n'
    printf '# category: identity (rofi theme / waybar config+style / wallpaper) | colors (generated palette)\n'
  } >"$pdir/manifest"
}

# ---------------------------------------------------------------------------
# Manifest reading
# ---------------------------------------------------------------------------
tp_meta() {
  # tp_meta <profile_dir> <key>
  [ -f "$1/manifest" ] || return 0
  awk -F'\t' -v k="$2" '$1==k {v=$2} END{ if (v!="") print v }' "$1/manifest"
}

tp_profile_exists() {
  [ -f "$(tp_profile_dir "$1")/manifest" ]
}

tp_show_profile_summary() {
  local name="$1" pdir
  pdir="$(tp_profile_dir "$name")"
  printf '%s\n' "$name"
  printf '    salvado : %s\n' "$(tp_meta "$pdir" created_human)"
  printf '    etiqueta: %s\n' "$(tp_meta "$pdir" tag)"
  printf '    rofi    : %s\n' "$(tp_meta "$pdir" rofi_theme)"
  printf '    fondo   : %s\n' "$(tp_meta "$pdir" wallpaper_source)"
  printf '    tamaño  : %s (%s)\n' "$(tp_human_size "$pdir")" "$pdir"
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
# tp_apply_rofi_theme <profile_dir> <live_config> <dry_run>
#   Surgical: swap only the effective @theme line, so unrelated edits the user
#   made to config.rasi after the snapshot are preserved. Falls back to the
#   stored full copy when the live config is gone.
tp_apply_rofi_theme() {
  local pdir="$1" live="$2" dry="${3:-0}"
  local want payload
  want="$(tp_meta "$pdir" rofi_theme)"
  payload="$(tp_payload_of "$pdir" "$TP_ROFI_CONFIG")"

  if [ -z "$want" ] || [ "$want" = "-" ]; then
    return 0
  fi

  if [ ! -f "$live" ]; then
    if [ -f "$payload" ]; then
      tp_info "  rofi  : config.rasi ausente -> se restaura la copia del perfil"
      if [ "$dry" = "1" ]; then
        return 0
      fi
      mkdir -p "$(dirname "$live")"
      cp -f -- "$payload" "$live"
      return 0
    fi
    tp_warn "rofi: config.rasi ausente y el perfil no tiene copia; se omite"
    return 0
  fi

  local tmp
  tmp="$(mktemp "${live}.themeprofile.XXXXXX")" || return 1

  # Keep every non-@theme line; drop only effective @theme lines, then append
  # the recorded one. Commented "// @theme" lines are user history -> untouched.
  awk -v want="$want" '
    /^[[:space:]]*@theme[[:space:]]/ { next }
    { print }
    END { printf "@theme \"%s\"\n", want }
  ' "$live" >"$tmp"

  if [ "$dry" = "1" ]; then
    tp_info "  rofi  : @theme -> $want  (dry-run, no se escribe)"
    rm -f "$tmp"
    return 0
  fi

  if cmp -s "$live" "$tmp"; then
    rm -f "$tmp"
    tp_info "  rofi  : @theme ya era $want (sin cambios)"
    return 0
  fi

  cp -f -- "$live" "${live}.themeprofile.bak" 2>/dev/null || true
  cp -f -- "$tmp" "$live" && rm -f "$tmp"
  tp_info "  rofi  : @theme -> $want"
  return 0
}

# tp_restore_one <profile_dir> <kind> <live> <rel> <link_raw> <ext_target> <dry>
tp_restore_one() {
  local pdir="$1" kind="$2" live="$3" rel="$4" link_raw="$5" ext="$6" dry="${7:-0}"
  local payload="$pdir/$rel"

  case "$kind" in
  file)
    if [ ! -f "$payload" ]; then
      tp_warn "  payload ausente para $live; se omite"
      return 0
    fi
    if [ "$dry" = "1" ]; then
      tp_info "  fichero: $live  <- $rel"
      return 0
    fi
    mkdir -p "$(dirname "$live")"
    rm -f "$live"
    cp -f -- "$payload" "$live"
    tp_info "  fichero: $live"
    ;;
  symlink)
    local target="$link_raw"
    if [ -z "$target" ] || [ "$target" = "-" ]; then
      tp_warn "  enlace $live sin destino registrado; se omite"
      return 0
    fi
    # Resolve the destination we should test for existence.
    local abs_target="$target"
    case "$target" in
    /*) ;;
    *) abs_target="$(dirname "$live")/$target" ;;
    esac
    if [ ! -e "$abs_target" ]; then
      if [ -f "$payload" ]; then
        tp_info "  enlace : destino ausente -> se recrea desde el perfil ($abs_target)"
        if [ "$dry" != "1" ]; then
          mkdir -p "$(dirname "$abs_target")"
          cp -f -- "$payload" "$abs_target"
        fi
      elif [ -n "$ext" ] && [ "$ext" != "-" ] && [ -f "$(tp_payload_of "$pdir" "$TP_WALLPAPER_COPY")" ] &&
        [ "$abs_target" = "$ext" ]; then
        # Wallpaper library file is gone; fall back to the copy kept in the profile.
        tp_info "  enlace : fondo original ausente -> se usa la copia del perfil"
        if [ "$dry" != "1" ]; then
          mkdir -p "$(dirname "$abs_target")"
          cp -f -- "$(tp_payload_of "$pdir" "$TP_WALLPAPER_COPY")" "$abs_target"
        fi
      else
        tp_warn "  enlace : $abs_target no existe y el perfil no puede recrearlo"
      fi
    fi
    if [ "$dry" = "1" ]; then
      tp_info "  enlace : $live -> $target"
      return 0
    fi
    mkdir -p "$(dirname "$live")"
    ln -sfn -- "$target" "$live"
    tp_info "  enlace : $live -> $target"
    ;;
  missing)
    tp_info "  ausente: $live (no existía al guardar; no se toca)"
    ;;
  *)
    tp_warn "  tipo desconocido '$kind' para $live; se omite"
    ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Reload -- mirrors the conventions already used by the repo's own scripts
# ---------------------------------------------------------------------------
tp_reload() {
  local wallpaper="${1:-}"

  # Hyprland border colours come from ~/.config/hypr/wallust/wallust-hyprland.conf
  if tp_have hyprctl; then
    hyprctl reload >/dev/null 2>&1 || true
    tp_info "  reload : hyprctl reload"
  fi

  # Waybar: SIGUSR2 does NOT reload the stylesheet on 0.15.0, so a real restart
  # is required. Same approach as WallustSwww.sh.
  # Deliberately NOT Refresh.sh: that script also pkills qs/rofi/swaync/ags.
  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -x waybar >/dev/null 2>&1 || true
    # Wait for the old process to really exit (up to ~2s) before starting a new
    # one, otherwise a slow shutdown can leave two bars on screen.
    local _i
    for _i in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -x waybar >/dev/null 2>&1 || break
      sleep 0.2
    done
    hyprctl dispatch exec waybar >/dev/null 2>&1 || true
    tp_info "  reload : waybar reiniciado (restart real, no SIGUSR2)"
  else
    tp_info "  reload : waybar no está corriendo; no se arranca"
  fi

  # Kitty picks up 01-Wallust.conf on SIGUSR1.
  if pidof kitty >/dev/null 2>&1; then
    local pid
    for pid in $(pidof kitty); do kill -SIGUSR1 "$pid" 2>/dev/null || true; done
    tp_info "  reload : kitty (SIGUSR1)"
  fi

  # Ghostty reloads its wallust.conf on SIGUSR2.
  if pidof ghostty >/dev/null 2>&1; then
    local pid
    for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
    tp_info "  reload : ghostty (SIGUSR2)"
  fi

  # swaync, when present.
  if pidof swaync >/dev/null 2>&1 && tp_have swaync-client; then
    swaync-client -R -rs >/dev/null 2>&1 || true
    tp_info "  reload : swaync"
  fi

  # Re-apply the wallpaper through swww, the same tool the repo's wallpaper
  # scripts use. Only when a daemon is actually answering.
  if [ -n "$wallpaper" ] && [ -f "$wallpaper" ] && tp_have swww; then
    if swww query >/dev/null 2>&1; then
      swww img -- "$wallpaper" >/dev/null 2>&1 || true
      tp_info "  reload : swww img $wallpaper"
    else
      tp_info "  reload : swww no responde; fondo no re-aplicado (los ficheros sí se restauraron)"
    fi
  fi
  return 0
}

# ---------------------------------------------------------------------------
# rofi picker (optional convenience, uses the repo's rofi conventions)
# ---------------------------------------------------------------------------
tp_pick_profile() {
  tp_have rofi || return 1
  local names
  names="$(tp_list_profiles)"
  [ -n "$names" ] || return 1
  printf '%s\n' "$names" | rofi -dmenu -i -p 'Restaurar tema' \
    -mesg 'Selecciona un perfil guardado. Esc cancela.'
}
