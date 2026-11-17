# Perfiles de tema — guardar / restaurar (Theme Profiles)

Volver siempre a tu configuración personal después de cambiar de tema.

`Super + T` ejecuta `~/.config/hypr/scripts/ThemeChanger.sh`, un *global Wallust
theme switcher*. Ese script sobrescribe los ficheros de color generados y el
selector de temas de rofi (`RofiThemeSelector.sh`) reescribe la línea `@theme` de
`~/.config/rofi/config.rasi`. Antes de esta herramienta **no había deshacer, ni
historial, ni forma de volver atrás**.

Esto es **aditivo**: no cambia el comportamiento de ningún script existente. La
única excepción, pequeña y reversible, es un *hook* en `ThemeChanger.sh`
(ver más abajo).

---

## Los dos comandos

```bash
# Guardar la identidad del tema actual
~/.config/hypr/scripts/ThemeProfileSave.sh mi-tema

# Volver a ese tema
~/.config/hypr/scripts/ThemeProfileRestore.sh mi-tema
```

Sin nombre, `Save` usa una marca de tiempo (`2026-09-18_234512`).

### Opciones útiles

| Comando | Qué hace |
| --- | --- |
| `ThemeProfileSave.sh --list` | lista los perfiles guardados |
| `ThemeProfileSave.sh -t "antes de probar Nord" mi-tema` | añade una etiqueta al manifest |
| `ThemeProfileSave.sh -w mi-tema` | sin la imagen del fondo (perfil mucho más ligero) |
| `ThemeProfileSave.sh -c mi-tema` | sin los ficheros de color generados |
| `ThemeProfileSave.sh --force mi-tema` | sobrescribe un perfil existente |
| `ThemeProfileRestore.sh --list` | lista los perfiles disponibles |
| `ThemeProfileRestore.sh --dry-run mi-tema` | muestra qué haría, **sin tocar nada** |
| `ThemeProfileRestore.sh --pick` | elige el perfil con rofi |
| `ThemeProfileRestore.sh -c mi-tema` | restaura **solo la identidad** (tema de rofi, waybar config+estilo, fondo), sin tocar los ficheros de color |
| `ThemeProfileRestore.sh -w mi-tema` | no vuelve a aplicar el fondo con swww |
| `ThemeProfileRestore.sh -R mi-tema` | solo ficheros, sin reiniciar waybar ni recargar |

`ThemeProfileRestore.sh` sin nombre restaura **`last-known-good`**, la foto
automática que se toma antes de cada cambio de tema. Es la red de seguridad.

---

## La red de seguridad: `last-known-good`

`ThemeChanger.sh` toma una foto **antes** de aplicar nada, así que ningún cambio
de tema vuelve a ser una puerta de un solo sentido:

```bash
~/.config/hypr/scripts/ThemeProfileRestore.sh            # equivale a ... last-known-good
```

El *hook* añadido a `ThemeChanger.sh` son 10 líneas (36–45), comentadas en el
propio script, justo después del `exit 0` de cancelación y antes de `start_ts`:

```bash
if [ -x "$HOME/.config/hypr/scripts/ThemeProfileSave.sh" ]; then
  "$HOME/.config/hypr/scripts/ThemeProfileSave.sh" --quiet --force last-known-good \
    --tag "auto: pre-cambio, choice=${choice}" || true
fi
```

Lleva `|| true`, así que **no puede romper `ThemeChanger.sh`**: si el guardado
falla, el cambio de tema sigue igual que antes.

### Revertir el hook (exacto)

```bash
cp -a ~/.config/hypr/scripts/ThemeChanger.sh /tmp/ThemeChanger.sh.con-hook
sed -i '36,45d' ~/.config/hypr/scripts/ThemeChanger.sh
bash -n ~/.config/hypr/scripts/ThemeChanger.sh     # debe salir sin errores
```

Es reversible también al revés: vuelve a insertar esas 10 líneas entre el `fi`
de la cancelación y el comentario `# Record time before applying`. Nada más del
script se ha tocado (el resto del diff es vacío).

### Alternativa sin tocar `ThemeChanger.sh`

Si prefieres no modificar nada existente, borra el hook con el comando de arriba
y crea tu propio wrapper:

```bash
~/.config/hypr/scripts/ThemeProfileSave.sh --quiet --force last-known-good -t "auto: pre-cambio"
~/.config/hypr/scripts/ThemeChanger.sh
```

…y apunta tu keybind ahí. La red de seguridad solo funciona si pasas por ese
camino; el hook dentro del script funciona siempre, se llame como se llame.

---

## Qué guarda un perfil

En `~/.config/theme-profiles/<nombre>/`, con un `manifest` y un árbol `files/`
que replica las rutas absolutas originales.

**Identidad** (`category: identity`)

| Ruta | Cómo se guarda |
| --- | --- |
| `~/.config/rofi/config.rasi` | la línea `@theme` activa **y** una copia entera del fichero |
| `~/.config/waybar/config` | fichero *o* enlace + su destino (`readlink` literal) |
| `~/.config/waybar/style.css` | enlace + destino, y el **contenido** del destino |
| `~/.config/hypr/wallpaper_effects/.wallpaper_current` | copia de la imagen |
| `~/.config/rofi/.current_wallpaper` | enlace |

**Color generado** (`category: colors`) — todos los targets declarados en
`~/.config/wallust/wallust.toml` y en `~/.config/matugen/config.toml`:

`waybar/wallust/colors-waybar.css`, `rofi/wallust/colors-rofi.rasi`,
`kitty/kitty-themes/01-Wallust.conf`, `hypr/wallust/wallust-hyprland.conf`,
`ghostty/wallust.conf`, `cava/config`,
`ags/style/abstracts/_variables.scss`, `swaync/wallust/colors-wallust.css`,
`gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`.

`~/.config/quickshell/qml_color.json` es un target de wallust/matugen, pero se
deja **fuera por defecto** para no tocar nada bajo la configuración de
quickshell. Añádelo con `--with-quickshell` al guardar y al restaurar.

### El perfil es autocontenido

Guarda rutas **absolutas** y los ficheros en sí, así que sigue siendo
restaurable aunque borres los originales: `config.rasi`, `waybar/config`,
`waybar/style.css`, el destino del enlace de estilo, el fondo o cualquier
fichero de color. Los ficheros del usuario **fuera** de `~/.config` (por ejemplo
una foto en `~/Imágenes/wallpapers/`) se referencian, no se duplican; si
desaparecen, la restauración usa la copia del fondo que sí está en el perfil.

---

## Qué hace la restauración

1. Sustituye **solo** la línea `@theme` de `config.rasi`, conservando el resto
   del fichero tal y como lo tengas (los comentarios `// @theme` no se tocan).
   Si `config.rasi` no existe, lo recrea desde la copia del perfil. Antes de
   escribir deja el anterior en `~/.config/rofi/config.rasi.themeprofile.bak`
   (un único fichero, se sobrescribe cada vez; bórralo si no lo quieres).
2. Repone cada entrada del manifest, respetando si era un fichero o un enlace.
3. Recarga (mismas convenciones que los scripts del repo):
   - `hyprctl reload` → bordes de Hyprland (`wallust-hyprland.conf`)
   - **reinicio real de waybar** (`pkill -x waybar` + `hyprctl dispatch exec waybar`).
     En Waybar 0.15.0 **`SIGUSR2` no recarga el CSS**, así que hace falta un
     reinicio; es lo mismo que ya hace `WallustSwww.sh`.
   - `SIGUSR1` a kitty, `SIGUSR2` a ghostty, `swaync-client -R -rs`
   - `swww img <fondo>` si el daemon responde
4. Es **idempotente**: ejecutarlo dos veces deja el mismo resultado, y no hace
   falta cerrar sesión.

**No llama a `Refresh.sh`** a propósito: ese script además mata
`waybar rofi swaync ags qs`, y matar `qs` se lleva por delante el
`controlcenter.service`. Una restauración no debería tener esos efectos.

---

## Atajos de teclado (opcional)

Añádelos tú a `~/.config/hypr/UserConfigs/UserKeybinds.conf` si quieres:

```conf
# Guardar el tema actual como perfil con nombre
bindd = SUPER SHIFT, S, Guardar perfil de tema, exec, $scriptsDir/ThemeProfileSave.sh

# Volver al perfil "last-known-good" (la foto previa al último cambio de tema)
bindd = SUPER SHIFT, R, Restaurar último tema bueno, exec, $scriptsDir/ThemeProfileRestore.sh last-known-good

# Elegir un perfil guardado con rofi
bindd = SUPER SHIFT, P, Elegir perfil de tema, exec, $scriptsDir/ThemeProfileRestore.sh --pick
```

`$scriptsDir` ya está definido en la configuración de JaKooLit. **Elige
combinaciones que no choquen** con tus binds actuales (`SUPER SHIFT R` ya está
usado por JaKooLit para el selector de temas de rofi, así que probablemente
quieras cambiar esa tecla). Revierte borrando las líneas que añadas.

---

## Ficheros de esta herramienta

```
~/.config/hypr/scripts/lib-theme-profiles.sh      # librería compartida (se sourcea, no se ejecuta)
~/.config/hypr/scripts/ThemeProfileSave.sh        # guardar
~/.config/hypr/scripts/ThemeProfileRestore.sh     # restaurar
~/.config/hypr/scripts/THEME-PROFILES.md          # este documento
~/.config/theme-profiles/<nombre>/                # los perfiles guardados
```

Nada de esto usa `sudo`, `git`, ni redes. El único fichero existente que se ha
tocado es `ThemeChanger.sh` (el hook de 10 líneas).

---

## Límites conocidos

- El **nombre** del tema de wallust no se guarda (wallust 3.5.2 no registra en
  ningún sitio el último `wallust theme -- X` aplicado). Lo que se guarda es el
  **resultado**: los ficheros de color generados. Restaurarlos reproduce el
  aspecto exacto, pero el "tema actual" que muestra tu terminal puede no
  coincidir con el del escritorio. `wallust theme list` sigue siendo la fuente
  de verdad para volver a aplicar un tema con nombre.
- `qml_color.json` no se restaura por defecto (ver arriba). Tampoco se reinicia
  `controlcenter.service`; el script solo reescribe el fichero de color.
- Restaurar `cava/config` y `gtk-3.0/gtk.css` / `gtk-4.0/gtk.css` sobrescribe
  esos ficheros con la copia del perfil. Si los editas a mano, usa `--no-colors`
  para restaurar solo la identidad.
- La imagen del fondo se copia dentro del perfil (~2,7 MB por perfil). Usa `-w`
  si te molesta el tamaño.
- `~/.config/quickshell/qml_color.json` no se restaura salvo `--with-quickshell`:
  wallust lo reescribe en cada cambio de tema, así que si no lo incluyes en el
  perfil quedará con la paleta del último tema aplicado.
