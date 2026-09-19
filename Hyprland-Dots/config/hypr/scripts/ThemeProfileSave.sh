#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
#
# ThemeProfileSave.sh -- guarda la identidad del tema actual como un perfil
# restaurable. Es una herramienta ADITIVA: no cambia ni aplica ningún tema.
#
#   ThemeProfileSave.sh [OPCIONES] [NOMBRE]
#
#   -l, --list          lista los perfiles existentes y sale
#   -f, --force         sobrescribe un perfil con el mismo nombre
#   -q, --quiet         sin notificaciones de escritorio
#   -t, --tag ETIQUETA  etiqueta libre en el manifest (p.ej. "pre-cambio")
#   -w, --no-wallpaper  no copia la imagen del fondo (perfil mucho más ligero)
#   -c, --no-colors     no guarda los ficheros de color generados
#       --with-quickshell
#                       incluye ~/.config/quickshell/qml_color.json (generado
#                       por wallust). Desactivado por defecto para no tocar nada
#                       bajo la configuración de quickshell.
#   -h, --help          esta ayuda
#
# Sin NOMBRE usa la marca de tiempo YYYY-MM-DD_HHMMSS (p.ej. 2026-09-18_234512).
#
# Lo que se guarda (ver lib-theme-profiles.sh para el detalle):
#   ~/.config/rofi/config.rasi                       (línea @theme activa + copia)
#   ~/.config/waybar/config                          (fichero o enlace + destino)
#   ~/.config/waybar/style.css                       (fichero o enlace + destino)
#   ~/.config/hypr/wallpaper_effects/.wallpaper_current
#   ~/.config/rofi/.current_wallpaper                (enlace)
#   + los ficheros de color generados por wallust/matugen
#     (waybar, rofi, kitty, ghostty, hyprland, cava, ags, swaync, gtk-3.0/4.0)
#     ~/.config/quickshell/qml_color.json solo con --with-quickshell.
#
# Restaurar:  ThemeProfileRestore.sh <NOMBRE>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib-theme-profiles.sh"

TP_QUIET=0
FORCE=0
WITH_QS=0
WITH_WALLPAPER=1
WITH_COLORS=1
TAG="manual"
NAME=""

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
  -l | --list)
    if tp_list_profiles | grep -q .; then
      echo "Perfiles en $TP_ROOT:"
      echo
      while IFS= read -r n; do tp_show_profile_summary "$n"; echo; done < <(tp_list_profiles)
    else
      echo "No hay perfiles todavía en $TP_ROOT"
    fi
    exit 0
    ;;
  -f | --force) FORCE=1 ;;
  -q | --quiet) TP_QUIET=1 ;;
  -w | --no-wallpaper) WITH_WALLPAPER=0 ;;
  -c | --no-colors) WITH_COLORS=0 ;;
  --with-quickshell) WITH_QS=1 ;;
  -t | --tag)
    [ $# -ge 2 ] || tp_die "--tag necesita un valor"
    TAG="$2"
    shift
    ;;
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

[ -n "$NAME" ] || NAME="$(tp_default_name)"
tp_valid_name "$NAME" || tp_die "nombre de perfil no válido: '$NAME' (usa letras, dígitos, . _ -)"

PDIR="$(tp_profile_dir "$NAME")"

if [ -e "$PDIR" ] && [ "$FORCE" != "1" ]; then
  tp_err "el perfil '$NAME' ya existe: $PDIR"
  tp_err "usa --force para sobrescribirlo, o elige otro nombre"
  exit 1
fi

# Build into a staging dir first so a failed save can never leave a half-written
# profile that looks restorable.
STAGE="${PDIR}.tmp.$$"
cleanup() { rm -rf -- "$STAGE"; }
trap cleanup EXIT

rm -rf -- "$STAGE"
mkdir -p "$STAGE/files"
tp_manifest_header "$STAGE" "$NAME" "$TAG" "$WITH_QS" || tp_die "no se pudo escribir el manifest"

captured=0
skipped=0
while IFS=$'\t' read -r category live; do
  [ -n "$live" ] || continue
  if [ "$category" = "colors" ] && [ "$WITH_COLORS" != "1" ]; then
    printf 'entry\t%s\tmissing\t%s\t-\t-\t-\t-\t-\tskipped_by_--no-colors\n' "$category" "$live" >>"$STAGE/manifest"
    skipped=$((skipped + 1))
    continue
  fi
  if [ "$live" = "$TP_WALLPAPER_COPY" ] && [ "$WITH_WALLPAPER" != "1" ]; then
    printf 'entry\t%s\tmissing\t%s\t-\t-\t-\t-\t-\tskipped_by_--no-wallpaper\n' "$category" "$live" >>"$STAGE/manifest"
    skipped=$((skipped + 1))
    continue
  fi
  if tp_capture_entry "$STAGE" "$live" "$category"; then
    captured=$((captured + 1))
  else
    skipped=$((skipped + 1))
  fi
done < <(tp_entry_paths "$WITH_QS")

# Remember the original wallpaper path so restore can re-apply it through swww.
if [ "$WITH_WALLPAPER" = "1" ] && [ -f "$STAGE/$(tp_relpath_of "$TP_WALLPAPER_COPY")" ]; then
  printf 'wallpaper_payload\t%s\n' "$(tp_relpath_of "$TP_WALLPAPER_COPY")" >>"$STAGE/manifest"
fi

mv -T -- "$STAGE" "$PDIR" 2>/dev/null || {
  rm -rf -- "$PDIR"
  mv -- "$STAGE" "$PDIR"
}
trap - EXIT

SIZE="$(tp_human_size "$PDIR")"
tp_info "Perfil guardado: $NAME"
tp_info "  ruta    : $PDIR"
tp_info "  tamaño  : $SIZE"
tp_info "  entradas: $captured (omitidas: $skipped)"
tp_info "  rofi    : $(tp_meta "$PDIR" rofi_theme)"
tp_info "  fondo   : $(tp_meta "$PDIR" wallpaper_source)"
tp_info ""
tp_info "Restaurar con: $SCRIPT_DIR/ThemeProfileRestore.sh $NAME"

tp_notify low "Tema guardado" "Perfil: $NAME ($SIZE)"
