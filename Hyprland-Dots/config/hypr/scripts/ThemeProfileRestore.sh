#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
#
# ThemeProfileRestore.sh -- devuelve el escritorio a un perfil guardado.
# Es idempotente (ejecutarlo dos veces deja el mismo resultado) y no necesita
# cerrar sesión.
#
#   ThemeProfileRestore.sh [OPCIONES] [NOMBRE]
#
#   -l, --list           lista los perfiles disponibles y sale
#   -p, --pick           elige el perfil con rofi
#   -n, --dry-run        muestra qué haría, sin tocar nada
#   -w, --no-wallpaper   no re-aplica el fondo con swww (los ficheros sí)
#   -R, --no-reload      solo restaura ficheros; no reinicia waybar ni recarga
#   -c, --no-colors      no restaura los ficheros de color generados (solo la
#                        identidad: tema de rofi, waybar config+estilo, fondo)
#   -q, --quiet          sin notificaciones de escritorio
#       --with-quickshell
#                       restaura también ~/.config/quickshell/qml_color.json si
#                       el perfil lo incluye
#   -h, --help           esta ayuda
#
# Sin NOMBRE usa el perfil de seguridad "last-known-good" (la foto automática
# que ThemeChanger.sh toma ANTES de cada cambio de tema) y, si no existe, abre
# el selector de rofi.
#
# Recargas que hace (las mismas convenciones que ya usan los scripts del repo):
#   hyprctl reload                -> bordes de Hyprland (wallust-hyprland.conf)
#   restart real de waybar        -> SIGUSR2 NO recarga el CSS en Waybar 0.15.0
#   SIGUSR1 a kitty, SIGUSR2 a ghostty, swaync-client -R -rs
#   swww img <fondo>              -> solo si el daemon responde
# Deliberadamente NO llama a Refresh.sh, porque ese script además mata
# qs/rofi/swaync/ags.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib-theme-profiles.sh"

TP_QUIET=0
DRY=0
RELOAD=1
WALLPAPER=1
WITH_QS=0
WITH_COLORS=1
NAME=""
PICK=0

usage() { sed -n '2,31p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

list_and_exit() {
  if tp_list_profiles | grep -q .; then
    echo "Perfiles en $TP_ROOT:"
    echo
    while IFS= read -r n; do tp_show_profile_summary "$n"; echo; done < <(tp_list_profiles)
  else
    echo "No hay perfiles todavía en $TP_ROOT"
    echo "Crea uno con: $SCRIPT_DIR/ThemeProfileSave.sh mi-tema"
  fi
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
  -l | --list) list_and_exit ;;
  -p | --pick) PICK=1 ;;
  -n | --dry-run) DRY=1 ;;
  -R | --no-reload) RELOAD=0 ;;
  -w | --no-wallpaper) WALLPAPER=0 ;;
  -c | --no-colors) WITH_COLORS=0 ;;
  --with-quickshell) WITH_QS=1 ;;
  -q | --quiet) TP_QUIET=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*)
    tp_err "opción desconocida: $1"
    usage >&2
    exit 2
    ;;
  *)
    [ -z "$NAME" ] || tp_die "solo se admite un nombre"
    NAME="$1"
    ;;
  esac
  shift
done

if [ "$PICK" = "1" ] && [ -z "$NAME" ]; then
  NAME="$(tp_pick_profile || true)"
  if [ -z "$NAME" ]; then
    echo "Selección cancelada."
    exit 0
  fi
fi

if [ -z "$NAME" ]; then
  if tp_profile_exists "$TP_LKG_NAME"; then
    NAME="$TP_LKG_NAME"
    tp_info "Sin nombre indicado -> usando el perfil de seguridad '$TP_LKG_NAME'"
  else
    tp_info "No hay perfil '$TP_LKG_NAME' todavía. Elige uno:"
    echo
    list_and_exit
  fi
fi

tp_valid_name "$NAME" || tp_die "nombre de perfil no válido: '$NAME'"
PDIR="$(tp_profile_dir "$NAME")"
tp_profile_exists "$NAME" || tp_die "no existe el perfil '$NAME' ($PDIR)"

# Column layout of the entry lines (see the loop below).
MANIFEST_FORMAT="$(tp_meta "$PDIR" format)"

WALLPAPER_PAYLOAD=""
WP_REL="$(tp_meta "$PDIR" wallpaper_payload)"
if [ -n "$WP_REL" ] && [ -f "$PDIR/$WP_REL" ]; then
  WALLPAPER_PAYLOAD="$PDIR/$WP_REL"
fi
SAVED_AT="$(tp_meta "$PDIR" created_human)"
if [ "$DRY" = "1" ]; then
  tp_info "[dry-run] Perfil: $NAME  --  salvado el $SAVED_AT"
else
  tp_info "Restaurando perfil: $NAME  --  salvado el $SAVED_AT"
fi

tp_info "  origen: $PDIR"
tp_info ""

# ---------------------------------------------------------------------------
# 1. The rofi theme line, restored surgically.
# ---------------------------------------------------------------------------
tp_apply_rofi_theme "$PDIR" "$TP_ROFI_CONFIG" "$DRY"

# ---------------------------------------------------------------------------
# 2. Everything else, straight from the manifest.
# ---------------------------------------------------------------------------
while IFS= read -r line; do
  case "$line" in
  entry*) ;;
  *) continue ;;
  esac
  # The manifest's own "format" field decides the column layout: v1 had 9
  # columns, v2 adds the category right after "entry". Counting fields instead
  # would be wrong here, because read(1) drops a trailing empty field and most
  # entries have an empty note.
  IFS=$'\t' read -r -a F <<<"$line"
  if [ "$MANIFEST_FORMAT" = "2" ]; then
    category="${F[1]}" kind="${F[2]}" live="${F[3]}" rel="${F[4]}" link_raw="${F[5]}" target="${F[6]}"
  else
    category="identity" kind="${F[1]}" live="${F[2]}" rel="${F[3]}" link_raw="${F[4]}" target="${F[5]}"
  fi
  if [ "$category" = "colors" ] && [ "$WITH_COLORS" != "1" ]; then
    tp_info "  omitido: $live (--no-colors)"
    continue
  fi
  # The rofi theme line was already handled surgically above.
  if [ "$live" = "$TP_ROFI_CONFIG" ]; then
    continue
  fi
  case "$live" in
  */quickshell/qml_color.json)
    if [ "$WITH_QS" != "1" ]; then
      tp_info "  omitido: $live (usa --with-quickshell para incluirlo)"
      continue
    fi
    ;;
  esac
  tp_restore_one "$PDIR" "$kind" "$live" "$rel" "$link_raw" "$target" "$DRY"
done <"$PDIR/manifest"

# ---------------------------------------------------------------------------
# 3. Reloads.
# ---------------------------------------------------------------------------
if [ "$DRY" = "1" ]; then
  tp_info ""
  tp_info "[dry-run] no se recarga nada y no se ha escrito ningún fichero."
  exit 0
fi

if [ "$RELOAD" = "1" ]; then
  tp_info ""
  tp_info "Recargando:"
  if [ "$WALLPAPER" = "1" ]; then
    tp_reload "${WALLPAPER_PAYLOAD:-}"
  else
    tp_reload ""
  fi
else
  tp_info ""
  tp_info "--no-reload: ficheros restaurados, sin recargas (waybar sigue con el CSS antiguo en memoria)"
fi

tp_info ""
tp_info "Listo. Perfil '$NAME' restaurado."
tp_notify normal "Tema restaurado" "Perfil: $NAME"
