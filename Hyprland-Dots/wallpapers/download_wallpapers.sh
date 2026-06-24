#!/usr/bin/env bash
# /* ---- 💫 Custom Wallpaper Downloader for 0o0-ct/Pixi-Arch-A Dotfiles 💫 ---- */

# Configuración de carpetas
REPO_WALLPAPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
SYSTEM_WALLPAPERS_DIR="$PICTURES_DIR/wallpapers"

# Colores para mensajes
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
RED="$(tput setaf 1)"
BLUE="$(tput setaf 4)"
RESET="$(tput sgr0)"

OK="[${GREEN}OK${RESET}]"
NOTE="[${YELLOW}NOTE${RESET}]"
INFO="[${BLUE}INFO${RESET}]"
ERROR="[${RED}ERROR${RESET}]"

echo "${INFO} Iniciando purga de fondos antiguos y descarga de nueva biblioteca 4K..."

# Limpieza total de fondos anteriores para evitar duplicados
echo "${NOTE} Limpiando biblioteca anterior..."
find "$REPO_WALLPAPERS_DIR" -type f -not -name "download_wallpapers.sh" -delete
if [ -d "$SYSTEM_WALLPAPERS_DIR" ]; then
  find "$SYSTEM_WALLPAPERS_DIR" -type f -delete
fi

# Asegurar que las carpetas existan
mkdir -p "$REPO_WALLPAPERS_DIR"
mkdir -p "$SYSTEM_WALLPAPERS_DIR"

# Lista de URLs 4K de Wallhaven (80 imágenes)
declare -a WALLHAVEN_URLS=(
  "https://w.wallhaven.cc/full/zp/wallhaven-zpoxyj.png"
  "https://w.wallhaven.cc/full/k8/wallhaven-k81776.jpg"
  "https://w.wallhaven.cc/full/rq/wallhaven-rqo8km.png"
  "https://w.wallhaven.cc/full/d8/wallhaven-d8er1l.jpg"
  "https://w.wallhaven.cc/full/rq/wallhaven-rqo8r7.jpg"
  "https://w.wallhaven.cc/full/e8/wallhaven-e8wejo.jpg"
  "https://w.wallhaven.cc/full/6l/wallhaven-6lw5ll.jpg"
  "https://w.wallhaven.cc/full/w5/wallhaven-w5mlmp.jpg"
  "https://w.wallhaven.cc/full/og/wallhaven-oglrv9.jpg"
  "https://w.wallhaven.cc/full/je/wallhaven-jev9xw.jpg"
  "https://w.wallhaven.cc/full/9o/wallhaven-9o8v98.jpg"
  "https://w.wallhaven.cc/full/83/wallhaven-83qyry.jpg"
  "https://w.wallhaven.cc/full/xe/wallhaven-xe6j7z.jpg"
  "https://w.wallhaven.cc/full/vp/wallhaven-vp9mz8.jpg"
  "https://w.wallhaven.cc/full/8o/wallhaven-8o7p52.jpg"
  "https://w.wallhaven.cc/full/6q/wallhaven-6qleyl.jpg"
  "https://w.wallhaven.cc/full/ex/wallhaven-exkoww.jpg"
  "https://w.wallhaven.cc/full/d6/wallhaven-d6kmkm.jpg"
  "https://w.wallhaven.cc/full/ml/wallhaven-ml9rqm.jpg"
  "https://w.wallhaven.cc/full/13/wallhaven-13odl3.jpg"
  "https://w.wallhaven.cc/full/p2/wallhaven-p2rlre.jpg"
  "https://w.wallhaven.cc/full/zy/wallhaven-zy3drg.jpg"
  "https://w.wallhaven.cc/full/od/wallhaven-od2d2p.jpg"
  "https://w.wallhaven.cc/full/qr/wallhaven-qrzpxq.jpg"
  "https://w.wallhaven.cc/full/ne/wallhaven-newpql.jpg"
  "https://w.wallhaven.cc/full/x8/wallhaven-x8lp7z.jpg"
  "https://w.wallhaven.cc/full/4l/wallhaven-4lxlq4.jpg"
  "https://w.wallhaven.cc/full/e8/wallhaven-e8xzgo.jpg"
  "https://w.wallhaven.cc/full/x6/wallhaven-x6mkyl.png"
  "https://w.wallhaven.cc/full/q2/wallhaven-q2kmw5.jpg"
  "https://w.wallhaven.cc/full/95/wallhaven-95ve78.jpg"
  "https://w.wallhaven.cc/full/x6/wallhaven-x655xl.jpg"
  "https://w.wallhaven.cc/full/je/wallhaven-je1lem.png"
  "https://w.wallhaven.cc/full/qr/wallhaven-qrzerd.png"
  "https://w.wallhaven.cc/full/we/wallhaven-wew59r.jpg"
  "https://w.wallhaven.cc/full/wy/wallhaven-wyy31x.png"
  "https://w.wallhaven.cc/full/13/wallhaven-138gd1.png"
  "https://w.wallhaven.cc/full/e7/wallhaven-e7zy1l.jpg"
  "https://w.wallhaven.cc/full/xe/wallhaven-xe6y6v.png"
  "https://w.wallhaven.cc/full/ne/wallhaven-neqwq8.jpg"
  "https://w.wallhaven.cc/full/m3/wallhaven-m33y19.jpg"
  "https://w.wallhaven.cc/full/76/wallhaven-763ryv.png"
  "https://w.wallhaven.cc/full/md/wallhaven-md21ly.jpg"
  "https://w.wallhaven.cc/full/z8/wallhaven-z8m3yg.jpg"
  "https://w.wallhaven.cc/full/zm/wallhaven-zm7x5o.jpg"
  "https://w.wallhaven.cc/full/zy/wallhaven-zyk92y.png"
  "https://w.wallhaven.cc/full/9m/wallhaven-9mjrzd.jpg"
  "https://w.wallhaven.cc/full/je/wallhaven-jexxe5.png"
  "https://w.wallhaven.cc/full/m3/wallhaven-m3d5x1.jpg"
  "https://w.wallhaven.cc/full/28/wallhaven-28qzvm.jpg"
  "https://w.wallhaven.cc/full/zy/wallhaven-zyyx1o.jpg"
  "https://w.wallhaven.cc/full/d6/wallhaven-d6zmkl.png"
  "https://w.wallhaven.cc/full/m9/wallhaven-m9y1zy.png"
  "https://w.wallhaven.cc/full/zy/wallhaven-zymp8o.png"
  "https://w.wallhaven.cc/full/je/wallhaven-jexovp.png"
  "https://w.wallhaven.cc/full/q6/wallhaven-q6ydp5.jpg"
  "https://w.wallhaven.cc/full/nz/wallhaven-nzv56y.png"
  "https://w.wallhaven.cc/full/x1/wallhaven-x1mpgd.jpg"
  "https://w.wallhaven.cc/full/v9/wallhaven-v9v828.jpg"
  "https://w.wallhaven.cc/full/wq/wallhaven-wq8mdr.jpg"
  "https://w.wallhaven.cc/full/og/wallhaven-ogxyml.png"
  "https://w.wallhaven.cc/full/p9/wallhaven-p9gvvm.jpg"
  "https://w.wallhaven.cc/full/d6/wallhaven-d6j7vl.png"
  "https://w.wallhaven.cc/full/3l/wallhaven-3lojmd.jpg"
  "https://w.wallhaven.cc/full/w5/wallhaven-w5qyxp.jpg"
  "https://w.wallhaven.cc/full/7p/wallhaven-7plxvv.png"
  "https://w.wallhaven.cc/full/jx/wallhaven-jxmd7m.jpg"
  "https://w.wallhaven.cc/full/z8/wallhaven-z8l67y.jpg"
  "https://w.wallhaven.cc/full/l8/wallhaven-l8q83l.png"
  "https://w.wallhaven.cc/full/q2/wallhaven-q21ezq.jpg"
  "https://w.wallhaven.cc/full/md/wallhaven-mdyzwm.png"
  "https://w.wallhaven.cc/full/2e/wallhaven-2el1z9.jpg"
  "https://w.wallhaven.cc/full/o3/wallhaven-o3gzdl.jpg"
  "https://w.wallhaven.cc/full/7p/wallhaven-7p6glo.png"
  "https://w.wallhaven.cc/full/d8/wallhaven-d882g3.jpg"
  "https://w.wallhaven.cc/full/wq/wallhaven-wqwxzx.jpg"
  "https://w.wallhaven.cc/full/d8/wallhaven-d8p65o.jpg"
  "https://w.wallhaven.cc/full/dp/wallhaven-dpyeym.png"
  "https://w.wallhaven.cc/full/w5/wallhaven-w5q1yx.png"
  "https://w.wallhaven.cc/full/28/wallhaven-28dlry.png"
  "https://w.wallhaven.cc/full/w5/wallhaven-w5mzmx.jpg"
  "https://w.wallhaven.cc/full/xe/wallhaven-xepyo3.jpg"
  "https://w.wallhaven.cc/full/po/wallhaven-poy55m.jpg"
  "https://w.wallhaven.cc/full/lm/wallhaven-lm7ex2.jpg"
  "https://w.wallhaven.cc/full/md/wallhaven-mdm85m.jpg"
  "https://w.wallhaven.cc/full/21/wallhaven-213wry.jpg"
  "https://w.wallhaven.cc/full/ml/wallhaven-ml1d3y.jpg"
  "https://w.wallhaven.cc/full/q6/wallhaven-q6jpl5.jpg"
  "https://w.wallhaven.cc/full/9d/wallhaven-9dj568.jpg"
  "https://w.wallhaven.cc/full/z8/wallhaven-z8yxyj.jpg"
  "https://w.wallhaven.cc/full/ey/wallhaven-eyl85r.jpg"
  "https://w.wallhaven.cc/full/83/wallhaven-83mgq1.jpg"
  "https://w.wallhaven.cc/full/21/wallhaven-21yoe9.png"
  "https://w.wallhaven.cc/full/ly/wallhaven-ly3rly.jpg"
  "https://w.wallhaven.cc/full/l8/wallhaven-l85vvp.jpg"
  "https://w.wallhaven.cc/full/96/wallhaven-96gkj8.jpg"
  "https://w.wallhaven.cc/full/21/wallhaven-21dm26.jpg"
  "https://w.wallhaven.cc/full/o3/wallhaven-o37vkp.png"
  "https://w.wallhaven.cc/full/lm/wallhaven-lmlykl.jpg"
  "https://w.wallhaven.cc/full/y8/wallhaven-y8ey7x.jpg"
  "https://w.wallhaven.cc/full/95/wallhaven-953mvx.jpg"
  "https://w.wallhaven.cc/full/rq/wallhaven-rqjxdq.jpg"
  "https://w.wallhaven.cc/full/q6/wallhaven-q6k7yd.jpg"
  "https://w.wallhaven.cc/full/vp/wallhaven-vpopdm.jpg"
  "https://w.wallhaven.cc/full/3q/wallhaven-3q3m7y.jpg"
  "https://w.wallhaven.cc/full/zp/wallhaven-zp8m8o.jpg"
  "https://w.wallhaven.cc/full/m3/wallhaven-m3vppm.jpg"
  "https://w.wallhaven.cc/full/6d/wallhaven-6dgqq7.jpg"
  "https://w.wallhaven.cc/full/d6/wallhaven-d6k32g.jpg"
  "https://w.wallhaven.cc/full/96/wallhaven-969qww.jpg"
  "https://w.wallhaven.cc/full/rq/wallhaven-rqy6zm.png"
  "https://w.wallhaven.cc/full/13/wallhaven-13ymkw.png"
  "https://w.wallhaven.cc/full/z8/wallhaven-z85mdg.png"
  "https://w.wallhaven.cc/full/l8/wallhaven-l8qw7y.jpg"
  "https://w.wallhaven.cc/full/ex/wallhaven-exooer.png"
  "https://w.wallhaven.cc/full/o3/wallhaven-o3km89.png"
  "https://w.wallhaven.cc/full/1p/wallhaven-1prql3.png"
  "https://w.wallhaven.cc/full/l8/wallhaven-l8edvl.jpg"
  "https://w.wallhaven.cc/full/v9/wallhaven-v93vw3.jpg"
  "https://w.wallhaven.cc/full/q2/wallhaven-q28v7r.jpg"
  "https://w.wallhaven.cc/full/6k/wallhaven-6krmpq.jpg"
  "https://w.wallhaven.cc/full/jx/wallhaven-jx6rwq.jpg"
  "https://w.wallhaven.cc/full/x6/wallhaven-x6x633.jpg"
  "https://w.wallhaven.cc/full/6l/wallhaven-6lolz7.jpg"
  "https://w.wallhaven.cc/full/d6/wallhaven-d69p5o.jpg"
  "https://w.wallhaven.cc/full/j3/wallhaven-j368mp.png"
  "https://w.wallhaven.cc/full/k8/wallhaven-k82m17.png"
  "https://w.wallhaven.cc/full/l8/wallhaven-l8xg8y.jpg"
  "https://w.wallhaven.cc/full/7j/wallhaven-7jj2g3.png"
  "https://w.wallhaven.cc/full/ly/wallhaven-ly25wr.png"
)

# Lista de URLs de Pexels (27 imágenes)
declare -a PEXELS_URLS=(
  "https://images.pexels.com/photos/9097090/pexels-photo-9097090.jpeg"
  "https://images.pexels.com/photos/8973095/pexels-photo-8973095.jpeg"
  "https://images.pexels.com/photos/12614931/pexels-photo-12614931.jpeg"
  "https://images.pexels.com/photos/36744302/pexels-photo-36744302.jpeg"
  "https://images.pexels.com/photos/4467594/pexels-photo-4467594.jpeg"
  "https://images.pexels.com/photos/11847657/pexels-photo-11847657.jpeg"
  "https://images.pexels.com/photos/33879244/pexels-photo-33879244.jpeg"
  "https://images.pexels.com/photos/14317488/pexels-photo-14317488.jpeg"
  "https://images.pexels.com/photos/36025191/pexels-photo-36025191.jpeg"
  "https://images.pexels.com/photos/26545224/pexels-photo-26545224.jpeg"
  "https://images.pexels.com/photos/13371857/pexels-photo-13371857.jpeg"
  "https://images.pexels.com/photos/13791908/pexels-photo-13791908.jpeg"
  "https://images.pexels.com/photos/29652327/pexels-photo-29652327.jpeg"
  "https://images.pexels.com/photos/17104397/pexels-photo-17104397.jpeg"
  "https://images.pexels.com/photos/16486236/pexels-photo-16486236.jpeg"
  "https://images.pexels.com/photos/37716209/pexels-photo-37716209.jpeg"
  "https://images.pexels.com/photos/35862532/pexels-photo-35862532.jpeg"
  "https://images.pexels.com/photos/28428590/pexels-photo-28428590.jpeg"
  "https://images.pexels.com/photos/34247737/pexels-photo-34247737.jpeg"
  "https://images.pexels.com/photos/11458867/pexels-photo-11458867.jpeg"
  "https://images.pexels.com/photos/11363271/pexels-photo-11363271.jpeg"
  "https://images.pexels.com/photos/32180816/pexels-photo-32180816.jpeg"
  "https://images.pexels.com/photos/5039418/pexels-photo-5039418.jpeg"
  "https://images.pexels.com/photos/33329010/pexels-photo-33329010.jpeg"
  "https://images.pexels.com/photos/33797646/pexels-photo-33797646.jpeg"
  "https://images.pexels.com/photos/31622920/pexels-photo-31622920.jpeg"
  "https://images.pexels.com/photos/9669091/pexels-photo-9669091.jpeg"
  "https://images.pexels.com/photos/29284111/pexels-photo-29284111.png"
  "https://images.pexels.com/photos/33978455/pexels-photo-33978455.jpeg"
  "https://images.pexels.com/photos/12696426/pexels-photo-12696426.jpeg"
  "https://images.pexels.com/photos/31622908/pexels-photo-31622908.jpeg"
  "https://images.pexels.com/photos/36025199/pexels-photo-36025199.jpeg"
  "https://images.pexels.com/photos/31216389/pexels-photo-31216389.jpeg"
  "https://images.pexels.com/photos/31216390/pexels-photo-31216390.jpeg"
  "https://images.pexels.com/photos/12970447/pexels-photo-12970447.jpeg"
  "https://images.pexels.com/photos/28648056/pexels-photo-28648056.jpeg"
  "https://images.pexels.com/photos/31622979/pexels-photo-31622979.jpeg"
  "https://images.pexels.com/photos/6985195/pexels-photo-6985195.jpeg"
  "https://images.pexels.com/photos/7135079/pexels-photo-7135079.jpeg"
  "https://images.pexels.com/photos/37953511/pexels-photo-37953511.jpeg"
  "https://images.pexels.com/photos/37497005/pexels-photo-37497005.jpeg"
)

# Función para descargar
download_image() {
  local url="$1"
  local dest_dir="$2"
  local filename=$(basename "$url" | cut -d'?' -f1)
  
  if [ -f "$dest_dir/$filename" ]; then
    echo "  ${NOTE} Ya existe: $filename (Omitido)"
    return 0
  fi

  echo -n "  ${INFO} Descargando $filename... "
  if wget -q -O "$dest_dir/$filename" "$url"; then
    echo "${GREEN}Completado!${RESET}"
  else
    # Reintento con curl en caso de que wget falle
    if curl -sL -o "$dest_dir/$filename" "$url"; then
      echo "${GREEN}Completado (curl)!${RESET}"
    else
      echo "${RED}Fallido!${RESET}"
      rm -f "$dest_dir/$filename"
    fi
  fi
}

# --- Fase 1: Wallhaven (4K Directo) ---
echo -e "\n${BLUE}=== Descargando de Wallhaven (4K Nativo) ===${RESET}"
for url in "${WALLHAVEN_URLS[@]}"; do
  download_image "$url" "$REPO_WALLPAPERS_DIR"
done

# --- Fase 2: Pexels (Original Máxima Resolución 4K+) ---
echo -e "\n${BLUE}=== Descargando de Pexels (Calidad Ultra HD) ===${RESET}"
for url in "${PEXELS_URLS[@]}"; do
  download_image "$url" "$REPO_WALLPAPERS_DIR"
done

# --- Fase 3: Copiar al Sistema ---
echo -e "\n${BLUE}=== Sincronizando con la carpeta activa del sistema ($SYSTEM_WALLPAPERS_DIR) ===${RESET}"
if cp -R "$REPO_WALLPAPERS_DIR"/* "$SYSTEM_WALLPAPERS_DIR/"; then
  # Eliminar el propio script de descarga de la carpeta activa del sistema para no contaminar
  rm -f "$SYSTEM_WALLPAPERS_DIR/download_wallpapers.sh"
  echo "${OK} Sincronización completada! Todos tus nuevos fondos están listos para usarse."
else
  echo "${ERROR} Error al copiar los archivos a $SYSTEM_WALLPAPERS_DIR"
fi

# --- Fase 4: Autoregenerar tema del sistema con Wallust ---
echo -e "\n${BLUE}=== Sincronizando tema estético global con Wallust ===${RESET}"
# Buscamos la primera imagen descargada para inicializar el tema
FIRST_WALL=$(find "$SYSTEM_WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | head -n 1)
if [ -n "$FIRST_WALL" ] && [ -f "$FIRST_WALL" ]; then
  echo "${INFO} Inicializando tema estético del sistema con: $(basename "$FIRST_WALL")"
  wallust run -s "$FIRST_WALL" > /dev/null 2>&1
  # Intentar ejecutar el script oficial de 0o0-ct/Pixi-Arch-A si existe para refrescar el backend de swww/awww
  SCRIPTS_DIR="$HOME/.config/hypr/scripts"
  if [ -f "$SCRIPTS_DIR/WallustSwww.sh" ]; then
    "$SCRIPTS_DIR/WallustSwww.sh" "$FIRST_WALL" > /dev/null 2>&1 &
  fi
  echo "${OK} El tema visual de tu sistema se ha adaptado automáticamente al fondo."
else
  echo "${NOTE} No se pudo autoregenerar el tema porque no se encontraron imágenes."
fi

echo -e "\n${GREEN}🎉 ¡Proceso de descarga finalizado con éxito!${RESET}"
echo "${NOTE} Presiona ${YELLOW}SUPER + W${RESET} para recargar y elegir tus nuevos fondos."
