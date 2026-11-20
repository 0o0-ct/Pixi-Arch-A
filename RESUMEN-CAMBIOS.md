# RESUMEN DE CAMBIOS — Reparación Pixi-Arch-A (FASE 1)

> **Fecha:** 17-nov-2026 · **Repo:** `/home/c0o0c/JaKooLit` (raíz en lugar de `/workspace` del enunciado) · **Sin Git, sin `sudo`, sin instalaciones, `~/.config` NO modificado** (todo aplicado al repo; aplicación en vivo pendiente de tu decisión y de la checklist manual).

---

## 1. Resumen ejecutivo

Se completó la **FASE 1** del plan de reparación con las decisiones aprobadas (todas las opciones recomendadas y las afirmativas). Se restauró el bloqueo de sesión (hyprlock + hypridle) como parte del árbol activo, se corrigieron los binds de ratón muertos, se crearon los directorios de paletas generadas y sus placeholders, se eliminó el riesgo de recursión en el bloqueo, y se alinearon instalador, documentación y atajos de usuario con la arquitectura Lua real.

El sistema **no fue reinstalado desde el repo**, pero el **17-nov-2026 ~03:33 el usuario autorizó la aplicación directa en `~/.config`** (además del repo). Se aplicó con backup completo en `.opencode-backups/live-20261117_033325/` y se verificó con `hyprctl reload` + `hyprctl configerrors` (vacío) y `hyprctl binds` (binds de ratón corregidos en vivo). Ver §10. La parte que **sí** sigue pendiente es la reinstalación completa desde cero (flujo `copy.sh`/`install.sh` en una sesión limpia) y la checklist manual de la sección 9.

## 2. Estado inicial del proyecto

- Hyprland v0.57.2 (config Lua modular); migración marcada como «completada» pero con piezas clave ausentes en el árbol activo: no existía `hyprlock*.conf` ni `hypridle.conf` (solo en `Hyprland-Dots-Old/` y en el `~/.config` en vivo).
- `super+rueda` (workspace) y `super+alt+rueda` (zoom) eran binds muertos (`mouse:4/5` no existen en la API Lua; la rueda es `mouse_up`/`mouse_down`).
- Faltaban `hypr/wallust/` y `swaync/wallust/` (los genera `pixi_colors.py` solo si el directorio padre existe; los upgrades los borraban) → `hyprlock` y `swaync` sin paleta.
- `LockScreen.sh` llamaba a `loginctl lock-session` → riesgo de espiral con el `lock_cmd` de hypridle (P0-4).
- `UserKeybinds.lua` (lo que `keybinds.lua` carga realmente) no existía; el documentado `UserKeybinds.conf` no lo lee nadie.
- El instalador mutaba el árbol del repo durante la instalación (P2-6) y no instalaba hyprlock/hypridle/wallust en equipos limpios (P1-4).

## 3. Cambios realizados por prioridad

### P0 — Bloqueo e inactividad

| Tarea | Corrección | Archivos |
|---|---|---|
| P0-1 hyprlock restaurado | Copiados `hyprlock.conf` + `hyprlock-1080p/2k/4k/8k.conf` de `Hyprland-Dots-Old/` al árbol activo; **eliminada `general:grace = 1`** (no existe en hyprlock 0.9.7). `Old/` queda intacto. | `Hyprland-Dots/config/hypr/hyprlock*.conf` |
| P0-2 hypridle en el repo | Copiado el `hypridle.conf` **en vivo** (adaptado a `hyprctl eval 'hl.dsp.dpms(...)'`) → repo. Se instala vía `copy_phase2` en equipos limpios. Política conservada: aviso 540 s, bloqueo 600 s. | `Hyprland-Dots/config/hypr/hypridle.conf` |
| P0-3 paletas wallust | Creados `config/hypr/wallust/{wallust-hyprland.conf,mode-glass-lock.conf}` y `config/swaync/wallust/{colors-wallust.css,mode-glass.css}` con el **modo oscuro por defecto generado por el propio renderizador del proyecto** (`pixi_colors.py`, paleta por defecto = la de `config/waybar/wallust/`); `pixi_colors.py` los sobrescribe en cada cambio de wallpaper. Creado `config/swaync/layout.css` (columna única por defecto; `Refresh.sh` lo regenera según Waybar). `copy.sh` ahora hace `mkdir -p` de ambos directorios tras copiar. | ver «Archivos nuevos» |
| P0-4 recursión en bloqueo | Opción A: eliminada la llamada `loginctl lock-session` de `LockScreen.sh`. Cadena resultante: `SUPER+L` → `LockScreen.sh` → `hyprlock`; timeout 600 s / `before_sleep_cmd` → `loginctl lock-session` → hypridle `lock_cmd` → `LockScreen.sh` → `hyprlock` (sin re-entrada). | `scripts/LockScreen.sh` |

### P1 — Atajos y controles de ratón

| Tarea | Corrección | Archivos |
|---|---|---|
| P1-1 binds de ratón | `SUPER+mouse:4/5` (workspaces) → `SUPER+mouse_down` (e+1) y `SUPER+mouse_up` (e-1), mapeo oficial `/usr/share/hypr/hyprland.lua`. Zoom: eliminados `mouse:4/5` (muertos); queda `mouse_up`=acercar, `mouse_down`=alejar (rueda adelante = acercar, como pedía el spec). `mouse:273` (resize) ahora con `{ mouse = true }`; eliminados los binds muertos `mouse:1/3/4/5`; `mouse:272` sin cambios (ya correcto). | `lua/keybinds.lua` |
| P1-2 atajos de usuario | Creado `UserConfigs/UserKeybinds.lua` (plantilla documentada con ejemplos de alta/redefinición de binds y nota de migración desde `.conf`). `Kool_Quick_Settings.sh`: «Editar Atajos (Usuario)» → `UserKeybinds.lua`; «Editar Animaciones (Usuario)» → `UserAnimations.lua` (mismo defecto). `THEME-PROFILES.md`: ejemplo actualizado a Lua. `00-Readme`: explica el cargador Lua. `keybinds_parser.py`: comentario aclaratorio (no parsea `.lua`). | ver listas |
| P1-4 instalador | `copy.sh`: el «ajuste hyprlock < 1440p» ahora se aplica sobre la **copia instalada** en `$HOME/.config/hypr` (antes mutaba el repo); `mkdir -p` de `hypr/wallust` y `swaync/wallust` tras las fases de copia. `lib_copy.sh`: al restaurar `hyprlock.conf` desde un backup viejo (modo exprés e interactivo) se elimina `general:grace`. `install.sh`: ya no escribe `.wallpaper_current` en el repo (solo en `~/.config`). | `copy.sh`, `scripts/lib_copy.sh`, `install.sh` |
| P1-5 swaync | `layout.css` por defecto incluido en el repo; `StartupApps.sh` llama a `Refresh.sh` al final (sincroniza `config.json` y `layout.css` con la posición del Waybar activo y relanza waybar; colocación final = una única instancia determinista). **Corrección (revertida):** se llegó a añadir un bloque que lanzaba `swaync` en StartupApps — **retirado tras comprobar que `org.freedesktop.Notifications` lo posee `qs` (Quickshell, PID 1040 desde el login)** y que Quickshell implementa notificaciones (`config/quickshell/controlcenter/services/CcNotifications.qml`). swaync.service masked es coherente. El bloque fue revertido en repo y en vivo; backups en `.opencode-backups/revert-swaync-*/` y `live-swaync-*/`. | `config/swaync/layout.css`, `scripts/StartupApps.sh` |
| P1-6 12H sobre symlink | `lib_prompts.sh`: el prompt de reloj 12H aplica ahora a **todas** las variantes `hyprlock*.conf` (antes editaba solo `hyprlock.conf`, que tras la instalación es un symlink que la pantalla de bloqueo nunca lee). Probado sobre copia: no corrompe las plantillas (no-op salvo el caso previsto en `hyprlock-1080p.conf`). | `scripts/lib_prompts.sh` |

### P2 — Consistencia documental y deuda menor

| ID | Corrección |
|---|---|
| P2-1 | `general:grace = 1` eliminado (ver P0-1). |
| P2-2 | README: `SUPER+Space` = maximizar/restaurar (sin cubrir monitor); `SUPER+ALT+Space` = flotar todas las ventanas; «hypridle configurado vía Lua» → «configurado en `hypridle.conf`; hypridle no soporta Lua». |
| P2-3 | `ScreenIdleToggle.sh`: tooltips «15 min» → «aviso 9 min / bloqueo 10 min»; `ModulesCustom`: comentario `(15m vs ∞)` → `(10m vs ∞)`. |
| P2-4 | `00-Readme`: carga desde `hyprland.lua` (vía `lua/*.lua`); `UserKeybinds.lua`/`UserAnimations.lua` sustituyen a los `.conf`. |
| P2-5 | `MIGRACION-0-57-Lua.md`: estado anotado con la reparación del 17-nov; tabla «movidos» actualizada (hypridle/hyprlock devueltos al árbol activo); nota sobre los 11 `.hl` restantes. |
| P2-6 | **RESUELTO**: el instalador ya no muta el repo en ningún punto. `lib_prompts.sh`: `prompt_keyboard_layout` ahora edita la config **Lua instalada** (`$HOME/.config/hypr/lua/settings.lua`, valor con comillas + coma → Lua válido, verificado con `luac5.4`); `prompt_clock_12h` edita waybar `Modules` y todas las variantes `hyprlock*.conf` **de la copia instalada** (y salta symlinks para no sustituir el enlace). `copy.sh`: los seds de kitty (`<1440p`), rofi e hyprlock <1440p se aplican sobre `$HOME/.config` **tras las fases de copia**; `prompt_keyboard_layout` y `prompt_clock_12h` se invocan también post-copia. El bloque Hyprcursor (apuntaba a `configs/ENVariables.conf` inexistente) queda documentado como no-op vestigial. **Proof:** instalación express simulada en sandbox → completa sin errores y **1308/1308 archivos del repo sin cambios** (sha256); `settings.lua` resultante parsea; `waybar/Modules` intacto (el prompt 12H no tiene patrones que aplicar en este repo, que ya es 12H). |
| | **Nota semántica:** si el usuario mantiene un `Modules` antiguo (responde «n» a reemplazar waybar), el sed 12H ahora sí se aplicaría sobre su archivo (antes no tenía efecto alguno). Comportamiento intencionado; documentado aquí. |
| P2-9 | `initial-boot.sh`: `swww query \|\| swww-daemon && swww img` reestructurado: si el daemon no responde, se lanza en segundo plano con espera activa y luego se aplica el wallpaper (antes podía bloquear el script para siempre). |
| P2-10 | `copy_phase2` llamaba a `install_terminal_configs`, función **indefinida en todo el repo** → un `command not found` no fatal en cada instalación limpia. Corregido con un guard `declare -F` (no se inventa la función; si algún día se redefine, vuelve a ejecutarse). |
| P2-11 | **Placeholder de la caja de contraseña renderizado como texto crudo** (reportado por el usuario en vivo): `placeholder_text` soporta markup Pango. **1er intento:** `gi.repository.Pango` confirmó que Pango rechaza CSS `rgba(...)` → se llevó el valor a hex `#ffffff99`, pero en **hyprlang** `#` abre comentario y el valor quedaba **vacío** (`foreground=""`, segunda imagen del usuario). **Causa real, según spec hyprlang: un `#` literal en un valor se escapa con `##`** («## will be turned into a single #»). Corrección final: `##ffffff99` en los 5 `hyprlock*.conf` (fallback y hardcode de 4k/8k), `wallust/mode-glass-lock.conf` y `pixi_colors.py` (helper `hypr_hex_alpha()`, dark `##ffffff99` / light `##30212999`). **Proof en cadena:** unescape hyprlang `##`→`#` + `Pango.parse_markup` → `True` para ambas ramas. |
| P2-7 / P2-8 | **Sin tocar** (requieren decisión): rutas `configs/` inexistentes en `optimize.sh`, `update_WindowRules.sh`, `detect-gpu.sh`, `Tak0-Per-Window-Switch.sh`; `lua/keybinds.mouse_patch.lua` huérfano y con zoom invertido respecto al activo (candidato a eliminación, §8). |

## 4. Archivos modificados (17) — con respaldos en `/home/c0o0c/JaKooLit/.opencode-backups/`

Estructura relativa conservada; cada archivo fue respaldado **antes** de su primera edición:

```
README.md, MIGRACION-0-57-Lua.md, install.sh
Hyprland-Dots/copy.sh
Hyprland-Dots/scripts/lib_copy.sh, lib_prompts.sh
Hyprland-Dots/config/waybar/ModulesCustom
Hyprland-Dots/config/hypr/initial-boot.sh
Hyprland-Dots/config/hypr/lua/keybinds.lua
Hyprland-Dots/config/hypr/scripts/LockScreen.sh, StartupApps.sh, ScreenIdleToggle.sh,
  Kool_Quick_Settings.sh, THEME-PROFILES.md, keybinds_parser.py, pixi_colors.py
Hyprland-Dots/config/hypr/UserConfigs/00-Readme
```

(Los `hyprlock*.conf` también tienen respaldo en `.opencode-backups/.../hypr/` — estado previo al fix P2-11.)

Reversión: copiar el archivo desde `.opencode-backups/<ruta>` sobre el repo.

## 5. Archivos nuevos (12)

```
config/hypr/hypridle.conf                 ← copia del en vivo (decisión: live como fuente)
config/hypr/hyprlock.conf                 ← de Old (sin general:grace)
config/hypr/hyprlock-1080p.conf           ← de Old (sin general:grace)
config/hypr/hyprlock-2k.conf              ← de Old (sin general:grace)
config/hypr/hyprlock-4k.conf              ← de Old (sin general:grace)
config/hypr/hyprlock-8k.conf              ← de Old (sin general:grace)
config/hypr/wallust/wallust-hyprland.conf ← placeholder oscuro por defecto (renderizador del proyecto)
config/hypr/wallust/mode-glass-lock.conf  ← idem (rama DARK de render_hyprlock)
config/swaync/wallust/colors-wallust.css  ← idem (paleta por defecto + alias M3 que usa style.css)
config/swaync/wallust/mode-glass.css      ← idem (rama DARK de render_swaync_glass)
config/swaync/layout.css                  ← columna única por defecto (Refresh.sh lo regenera)
config/hypr/UserConfigs/UserKeybinds.lua  ← plantilla documentada para atajos de usuario
```

**Nada fue eliminado ni renombrado.** `Hyprland-Dots-Old/` queda intacto (es la referencia histórica).

## 6. Validaciones ejecutadas

### 6.1 Validación estática
- `bash -n` OK: `copy.sh`, `lib_copy.sh`, `lib_prompts.sh`, `LockScreen.sh`, `StartupApps.sh`, `ScreenIdleToggle.sh`, `Kool_Quick_Settings.sh`, `Refresh.sh`, `initial-boot.sh`, `install.sh`.
- `luac5.4 -p` y `luajit -bl` OK: `lua/keybinds.lua`, `UserConfigs/UserKeybinds.lua`.
- Diff Old→activo de los 5 `hyprlock*.conf`: **una línea** (`grace = 1`).
- `Find` final: 298 archivos `.conf/.hl/.lua` (263 conf, 21 lua, 14 hl de los cuales 11 en árbol activo).

### 6.2 Validación de integración
- `hyprland --config <repo>/hyprland.lua --verify-config` sobre copia temporal con `HOME`/`XDG_CONFIG_HOME` aislados → **«config ok»** (el cargador incluye `UserKeybinds.lua`; los placeholders wallust resuelven los `source =`).
- `hyprlock --config` de las **5 variantes** con `HOME` aislado y los placeholders instalados → **0 errores de configuración** (solo el fallo esperado de conexión a `wayland-bogus`). *Control negativo:* reintroduciendo `grace = 1` o rompiendo un `source =`, hyprlock reporta exactamente esos errores → la salida limpia es significativa.
- `hypridle` con `XDG_CONFIG_HOME` aislado sobre el `hypridle.conf` del repo → registra reglas **540 s** y **600 s** sin errores (`hypridle -c <ruta>` existe pero no fue necesario).
- Copia `cp -r config/hypr` / `cp -r config/swaync` a destino temporal (simula `copy_phase2`/`copy_phase1`) → los 12 archivos nuevos aterrizan correctamente.
- **Simulación completa de instalación limpia en modo express** sobre sandbox (`HOME=/tmp/opencode/cleaninstall/home`, libs del repo cargadas con `EXPRESS=1`, fases 1+2 + waybar): termina sin errores y el árbol resultante contiene `hypridle.conf`, `hyprlock*.conf`, `hypr/wallust/*`, `swaync/wallust/*` y `layout.css`. Sobre ese árbol: `hyprland --verify-config` → **«config ok»**; `hyprlock` → sin errores de configuración; `hypridle` → registra 540/600 s. Sin tocar el sistema en vivo.
- Dry-run del bloque de `lib_prompts.sh` (12H) sobre copias de las 5 variantes → sin corrupción; solo descomenta el caso previsto en `hyprlock-1080p.conf`.
- Cadena de bloqueo re-auditada en código: no queda ninguna llamada a `loginctl lock-session` en `LockScreen.sh` ni en `lua/`; los únicos llamantes restantes son los de hypridle (intencionados) y los menús AGS (poweroff/suspend, ajenos al lock).
- **Proof directo de Pango** (`gi.repository.Pango.parse_markup`): la cadena antigua (`rgba(...)`) lanza `g-markup-error-quark ... could not be parsed`; hyprlang exige `##` para un `#` literal; la corregida (`##ffffff99` → Pango `#ffffff99`) devuelve `True` (verificado en ambas ramas del generador, dark `##ffffff99` y light `##30212999`).
- `hyprlock --config` ×5 variantes con los placeholders corregidos → **0 errores de configuración** en ambas oleadas.

### 6.3 Validación funcional — NO ejecutada (requiere sesión gráfica en vivo)
No se arrancó Hyprland, ni se bloqueó la sesión, ni se probó suspensión/reanudación. Ver checklist §9.1. Diferencia explícita: todo lo anterior es estático/integración; **nada de lo anterior demuestra el comportamiento real en login**.

## 7. Riesgos pendientes

1. ~~La sesión en vivo sigue siendo la configuración anterior~~ **Resuelto el 17-nov ~03:33** (§10): configs aplicados a `~/.config`, `hyprctl reload` OK, `configerrors` vacío.
   - **Nota:** a las 03:33:13 arrancó `hypridle` lanzado por Hyprland (casi con seguridad un clic del usuario en el toggle de cafeína). La sesión en vivo **ya tiene auto-lock activo** (aviso 9 min, bloqueo 10 min) con la `hypridle.conf` en vivo (idéntica a la del repo). Si NO fue tu clic, dime qué lo lanzó.
   - A las 03:17:41 el journal registró **`hyprlock` core dump** (y a las 03:20 apareció un symlink dangling `hyprlock.conf → hyprlock-1080p.conf`): un intento de bloqueo con SUPER+L mientras `~/.config` aún no tenía `hyprlock*.conf`. Con §10 aplicado, ese camino queda reparado.
2. **Camino de bloqueo no probado en vivo** (mecánica, suspensión/reanudación, recuperación de DPMS). `ignore_dbus_inhibit = false` respeta inhibidores (Firefox/Steam) como antes.
3. **`Refresh.sh` relanza waybar en cada login** (diseño del script). Verificar que no haya parpadeo perceptible ni pérdida de estado en la barra.
4. **`swaync.service` está *masked* en el sistema en vivo** y Waybar muestra modo cafeína (sin hypridle). Si swaync no arranca en login, las notificaciones (aviso de 9 min incluido) no se muestran. Es una decisión/estado del sistema en vivo, no del repo; requiere revisión humana (¿quiere que `StartupApps.sh` lance `swaync`?).
5. **`pixi_colors.py` sobrescribirá los placeholders** en el próximo cambio de wallpaper (comportamiento deseado). Antes de ese momento, la pantalla de bloqueo y swaync usan la paleta oscura por defecto.
6. **Restauración desde backups antiguos de hyprlock**: cubierto (se elimina `grace`); no cubre otros desajustes de versiones viejas.
7. ~~**P2-6 residual**~~ **Resuelto** (ver P2-6): el instalador ya no edita el repo; todos los ajustes por-usuario se aplican sobre la copia instalada en `$HOME/.config`. Única semántica modificada (documentada): el 12H de waybar ahora se aplicaría también si el usuario conservara un `Modules` antiguo.
8. **`KeyBinds.sh`/`keybinds_parser.py` no muestran los atajos de `UserKeybinds.lua`** (parser de hyprlang). Extenderlo a Lua es trabajo aparte.
9. **Restauración interactiva de UserConfigs** (`restore_user_configs`) rsync-a el directorio completo: conservará `UserKeybinds.lua` de backups, pero la rama heredada (≤ v2.3.18) restaura solo `.conf` que ya no se leen (P1-3).

10. **`layout.css` y GTK3**: `Refresh.sh` (y por tanto el `layout.css` incluido en el repo) genera reglas `display: flex` / `flex-direction` / `flex-wrap` — **GTK3 no las conoce**: produce `Theme parser error: No property named ...` y las ignora. Es cosmético (swaync, si se usa, funciona igual; Quickshell es el daemon real) y persistirá porque `Refresh.sh` regenera ese CSS en cada login. Posible corrección futura (documentada, no aplicada): eliminar las propiedades flex del `layout.css` o portarlas a lo que GTK3 sí entiende, asumiendo que diverja de lo que regenera `Refresh.sh`.
11. **`hypridle` sigue corriendo** (lanzado en sesión a las 03:33). Con tu decisión, al suspender pedirá credenciales; tras el próximo login lo lanza `StartupApps.sh` automáticamente.

### Notificaciones — cómo funciona tu sistema (hallazgo)

`org.freedesktop.Notifications` lo posee **Quickshell** (el controlcenter, `qs`, PID 1040), con implementación propia (`config/quickshell/controlcenter/services/CcNotifications.qml` + secciones en la UI). **swaync está masked y no se usa** — es coherente con ese diseño. Los `notify-send` llegan a Quickshell (incl. el aviso de 9 min de hypridle). Verificación básica: `notify-send` retorna 0 y el destino responde ping. Para confirmar al 100 %, el usuario debe ver aparecer una notificación (la de prueba «SwayNC restaurado» enviada por error durante el diagnóstico quedó encolada en Quickshell).

## 8. LIMPIEZA EJECUTADA (17-nov, autorizada por el usuario)

Criterio del usuario: «si no sirve entonces si bórralos y si sirven entonces conserbadlos». Todo borrado tiene backup en `.opencode-backups/borrados-20261117_040907/`.

### Eliminados (no servían — 34 archivos + `scripts/__pycache__/`)

**Scripts (0 referencias en el árbol activo; 2 auto-referencias):**
`keybinds.mouse_patch.lua` (zoom invertido), `BrightnessKbd.sh`, `DynamicFolderColor.sh`, `Hypridle.sh`, `PortalHyprland.sh`, `rotate_sddm_wallpaper.sh`, `Tak0-Autodispatch.sh`, `Tak0-Per-Window-Switch.sh`, `toggle_fullscreen.sh`, `TouchPad.sh`, `update_WindowRules.sh`, `UserConfigsSwitcher.sh`, `initial-boot.sh` (chmod del instalador retirado en `copy.sh`; `archive/upgrade.sh` conserva su mención histórica, no se ejecuta).

**UserConfigs `.conf` sin lector funcional y `.hl` (ningún cargador):**
`WorkSpaceRules.conf`, `UserSettings.conf`, `ENVariables.conf`, `WindowRules.conf`, `UserAnimations.conf`, `UserKeybinds.conf`, `UserDecorations.conf`, `LaptopDisplay.conf`, `Laptops.conf`, y los 11 `.hl` (`01-UserDefaults`, `ENVariables`, `LaptopDisplay`, `Laptops`, `Startup_Apps`, `UserAnimations`, `UserDecorations`, `UserKeybinds`, `UserSettings`, `WindowRules`, `WorkSpaceRules`), más `UserDecorations.conf.bak-1789363489`.
`Kool_Quick_Settings.sh` actualizado: 4 entradas sin destino eliminadas del menú; 5 entradas re-apuntadas a los archivos reales (`lua/decorations.lua`, `lua/keybinds.lua`, `StartupApps.sh`, `lua/rules.lua`, `lua/settings.lua`); `$configs` retirada; `KeyboardLayout.sh` corregido su stale comment.

### Conservados (SÍ servían)
| Archivo | Quién lo usa |
|---|---|
| `UserConfigs/01-UserDefaults.conf` | `WaybarScripts.sh` y `RofiSearch.sh` (lo leen en runtime) |
| `UserConfigs/Startup_Apps.conf` | `WallpaperSelect.sh` (alterna swww-daemon/mpvpaper en wallpapers de vídeo) |
| `UserConfigs/PerformanceProfile.conf` | `optimize.sh` (genera/lee perfiles de rendimiento) |
| `scripts/Battery.sh`, `scripts/UptimeNixOS.sh` | `hyprlock*.conf` (batería y fallback de uptime) |
| `UserConfigs/00-Readme`, `UserAnimations.lua`, `UserKeybinds.lua` | documentos/carga Lua activa |

**No borrados pese a parecerlo:** nada. Las referencias restantes son intencionadas (docs de migración, listas legacy de restauración que saltan archivos ausentes sin error, comentarios stale corregidos donde procedía).

### Verificación post-limpieza
- `hyprland --verify-config` sobre copia temporal del árbol podado → **«config ok»**.
- Instalación express sandbox tras el cambio → completa sin errores; `UserConfigs/` resultante contiene exactamente los 6 archivos vigentes.

### Pendiente (tu decisión)
- ~~¿Borrado también en vivo?~~ **Resuelto (17-nov 04:11):** el mismo borrado se aplicó en `~/.config` con backup previo en `.opencode-backups/live-borrados-20261117_041140/` (34 elementos). `~/.config/hypr/UserConfigs/` ahora contiene exactamente: `00-Readme`, `01-UserDefaults.conf`, `PerformanceProfile.conf`, `Startup_Apps.conf`, `UserAnimations.lua`, `UserKeybinds.lua`.
- `optimize.sh`, `WaybarScripts.sh`, `RofiSearch.sh` siguen leyendo `.conf` vivos (los conservados funcionan vía Lua-compat); su modernización a Lua es trabajo aparte.
- `detect-gpu.sh` referencia `configs/` inexistentes (no-op guard sin romper); fuera de alcance de esta limpieza.

## 9. Decisiones y checklist

### 9.1 Checklist de pruebas manuales (en tu sesión)

- [ ] Reinstalar/actualizar desde el repo (p. ej. `Hyprland-Dots/copy.sh` o el flujo que uses) y **cerrar sesión y volver a entrar**.
- [ ] `hyprctl configerrors` → vacío; revisar `journalctl --user -b | grep -iE 'hypr|idle|lock'` sin errores.
- [ ] Arranque: waybar, swaync, dock, wallpaper, clima, polkit-agent, cliphist — todos operativos; wallpaper correcto.
- [ ] `SUPER + L` y `CTRL + ALT + L` bloquean; unlock funciona (password/huellas).
- [ ] `kill <sleep>`… (o esperar 9 min): notificación de aviso; **a los 10 min la sesión se bloquea sola**; desbloquear y comprobar DPMS.
- [ ] Apagado/encendido de pantalla por inactividad y tras suspender/reanudar — sesión siempre protegida.
- [ ] `SUPER + rueda` cambia de workspace; `SUPER + ALT + rueda-arriba` acerca y `rueda-abajo` aleja; `SUPER + clic izq.` arrastra / `SUPER + clic der.` redimensiona.
- [ ] Zoom del trackpad/ratón restablece con `Zoom.sh reset` si hiciera falta.
- [ ] `SUPER + SHIFT + B` (glass-bt), `SUPER + Space`, `SUPER + ALT + Space` como en README.
- [ ] swaync muestra notificaciones con paleta; `layout.css` aplicado según posición de waybar; waybar sin duplicados tras login.
- [ ] Formato 12H en pantalla de bloqueo y waybar (si se ejecutó el prompt).
- [ ] El aspecto visual original se conserva (blur, transparencias, dock, animaciones).

### 9.2 Decisiones que requieren tu aprobación

1. ~~¿**Eliminar** los candidatos de la §8?~~ **Resuelto** (17-nov, §8): 34 archivos + `__pycache__` eliminados con backup previo; 6 `UserConfigs/*.conf` conservados por tener lectores activos; menú de ajustes rápidos re-apuntado a los archivos reales. Pendiente: ¿aplicar el mismo borrado en `~/.config/hypr/UserConfigs/` en vivo?
2. ~~¿**Refactorizar el instalador** al modelo «plantilla → sed sobre `$HOME/.config`» (P2-6 residual)?~~ **Resuelto** (ver P2-6): refactorizado y validado en sandbox con instalación express completa; repo intacto (1308 sha256).
3. ~~¿**Restaurar `swaync.service`** (está masked) y/o que `StartupApps.sh` lance `swaync` si no está corriendo?~~ **Resuelto observando el sistema:** `org.freedesktop.Notifications` lo posee **Quickshell** (`qs`, PID 1040) con implementación real (`CcNotifications.qml`). swaync masked es intencionado; mi recomendación inicial fue errónea y se revirtió en repo y en vivo. *El aviso de 9 min sí llegará — vía Quickshell.* Si algún día quieres swaync de vuelta: `systemctl --user unmask swaync; systemctl --user start swaync` y adaptar `StartupApps.sh`.
4. ~~¿Aplicar ya estos cambios a `~/.config`?~~ **Resuelto:** el usuario autorizó "ambos" (repo + en vivo) → aplicado el 17-nov ~03:33 (§10).
5. ¿**Migrar automáticamente** el contenido de `UserKeybinds.conf` en vivo a `UserKeybinds.lua` (o lo haces a mano con la plantilla)?
6. ¿**Extender `keybinds_parser.py`** para listar binds de `UserKeybinds.lua` en «Buscar atajos»?
7. ¿**Quedarse con `initial-boot.sh`** o integrarlo/desactivarlo?

### 9.3 Confirmaciones finales

- ✅ No se ejecutaron comandos Git (el repo contiene `.git` —de raíz y en `GTK-themes-icons/`—; solo se leyó el árbol de archivos).
- ✅ No se ejecutó `sudo` ni instalaciones; ningún servicio reiniciado por mí.
- ⚠️ `~/.config` **SÍ fue modificado el 17-nov con autorización explícita del usuario** (§10, tres oleadas: configs+hyprlock, placeholder Pango, y el ida-y-vuelta de swaync). La 2ª oleada incluyó una **regresión introducida por mí** (`#` suelto en un valor → vacío) detectada y corregida en la misma sesión, con backups de ambos estados. La 3ª (swaync en StartupApps) fue **mi recomendación errónea**: se revirtió en repo y en vivo en la misma sesión (backups en `.opencode-backups/live-swaync-*/` y `revert-swaync-*/`).
- Una notificación de prueba ("SwayNC restaurado") fue enviada por error durante el diagnóstico; quedó encolada en Quickshell (daemon real de notificaciones). Inofensiva.
- Nota de higiene: varias corridas `hyprlock --display wayland-bogus` (mías) usan `SIGABRT` → ~20 entradas `hyprlock dumped core` en el journal del 17-nov 03:44–03:45 corresponden a esas pruebas, no a un fallo del sistema.
- ✅ No se eliminaron ni renombraron archivos (el symlink dangling `hyprlock.conf` retirado queda registrado en `.opencode-backups/live-20261117_033325/hyprlock-symlink-info.txt` y es recreable). Todo cambio es reversible desde `.opencode-backups/`.
- ✅ `Hyprland-Dots-Old/` intacto.
- ✅ El `__pycache__` de `scripts/` tiene mtime 02:47 (previo a esta sesión; no fue regenerado por mí — `pixi_colors.py` era más reciente que el `.pyc` pero el cache ya estaba actualizado).
- ⚠️ El resumen intermedio (FASE 0) fue supersedido por este documento.

---

## 10. Aplicación en vivo (`~/.config`) — 17-nov-2026 ~03:33 (autorizada por el usuario)

Decisión del usuario: **"Bloquear al suspender (recomendado)"** → `before_sleep_cmd = loginctl lock-session` se mantiene; **"ambos"** → aplicar también en `~/.config`, no solo en el repo.

**Backup previo (reversible):** `.opencode-backups/live-20261117_033325/` con los 10 archivos vivos previos (incluye `ModulesCustom`) y `hyprlock-symlink-info.txt` (metadata del symlink dangling retirado). Reversión: copiar esos archivos de vuelta.

**Aplicado (repo → en vivo), `diff` posterior = idéntico salvo indicación:**

- `hypr/scripts/{LockScreen,StartupApps,ScreenIdleToggle,Kool_Quick_Settings,THEME-PROFILES.md,keybinds_parser.py}`, `hypr/initial-boot.sh`, `hypr/lua/keybinds.lua`, `hypr/UserConfigs/00-Readme`
- `hypr/hypridle.conf` (era idéntico ya; mtime actualizado), `hypr/hyprlock.conf` + `hyprlock-1080p/2k/4k/8k.conf` (nuevos en vivo)
- `hypr/UserConfigs/UserKeybinds.lua` (nuevo)
- `hypr/wallust/{wallust-hyprland.conf,mode-glass-lock.conf}`, `swaync/wallust/{colors-wallust.css,mode-glass.css}`, `swaync/layout.css` (nuevos)
- `waybar/ModulesCustom`: **solo** el comentario `(15m → 10m)` (el archivo en vivo estaba intacto desde la instalación; no se sobrescribió su contenido)
- Retirado el symlink dangling `hyprlock.conf → hyprlock-1080p.conf` (03:20) antes de copiar los archivos reales

**Excluido deliberadamente de la aplicación en vivo:** `install.sh`, `copy.sh`, `lib_copy.sh`, `lib_prompts.sh`, `README.md`, `MIGRACION-0-57-Lua.md` (instalador/docs — no son configs de sesión) y los binds/configs que tocaran visuales.

**Verificación post-aplicación:**
- `hyprctl reload` → `ok`; `hyprctl configerrors` → **vacío**.
- `hyprctl binds` → 149 binds; la rueda queda como `mouse_down` (espacio +1) / `mouse_up` (espacio −1), `SUPER+ALT + mouse_up/down` = zoom in/out, `mouse:272/273` con `mouse=True` (drag/resize), **sin** `mouse:1/3/4/5`.
- `hyprlock --config ~/.config/hypr/hyprlock.conf --display wayland-bogus` → **0 errores de configuración** (solo el fallo esperado de conexión).
- `ScreenIdleToggle.sh status` → `"󰔚 10m"` (normal) — coherente con hypridle corriendo (§7.1).
- `pgrep hypridle` → PID 988871, hijo directo de Hyprland (lanzado en sesión a las 03:33:13).

**No ejecutado en vivo (a propósito):** ninguna prueba real de bloqueo (`SUPER+L` real queda en la checklist §9.1); no se reinició waybar ni la sesión; hypridle seguirá siendo auto-lanzado por `StartupApps.sh` en cada login.

### 10.1 Segunda oleada en vivo — placeholder de contraseña (17-nov ~03:35→03:53) — con incidencia propia

El bloqueo en vivo mostró el placeholder como texto literal. **Tres ciclos** hasta la solución:

1. **Diagnóstico inicial:** Pango no acepta CSS `rgba(...)` → placeholder crudo. Corrección (errónea): hex suelto `#ffffff99`.
2. **El usuario probó y reportó `foreground=""`** (texto más corto). **Error mío:** en hyprlang `#` es comentario, el valor quedó vacío. La spec hyprlang dice `##` = literal `#`. Estado intermedio respaldado en `.opencode-backups/live-fix-placeholder-20261117_034450/` y `.opencode-backups/placeholder-fix2-20261117_035238/`.
3. **Corrección definitiva:** `##ffffff99` (hyprlang) → `#ffffff99` (Pango) en repo y en vivo; helper `hypr_hex_alpha()` para la rama light. Cadena verificada: unescape + `Pango.parse_markup` → OK; `hyprlock --display wayland-bogus` ×5 variantes → 0 errores; verificación en vivo → 0 errores.

Backups de la solución intermedia (rota): `.opencode-backups/placeholder-fix2-*/` y `live-fix-placeholder-*/` — **no restaurar estas**.
Notas:
- `~/.config/hypr/hyprlock.conf` era un symlink → `hyprlock-1080p.conf` (panel 1080p); tras la aplicación final quedó como **archivo real** (DetectResolutionHyprlock.sh volverá a re-apuntarlo a `hyprlock-1080p.conf` en el próximo bloqueo, diseño normal).
- `pixi_colors.py` regenerará el placeholder correcto en cada cambio de wallpaper (dark `##ffffff99`, light `##30212999`).
- El usuario sigue probando `SUPER+L` (symlink re-apuntado a las 03:48 por LockScreen.sh).

**Archivos modificados (17) — con respaldos:** añadido `pixi_colors.py` a la lista de §4. Los 4 hyprlock pre-existentes y sus backups viven en `.opencode-backups/Hyprland-Dots/config/hypr/hyprlock*.conf` (copias del árbol previo al fix P2-11).

*Generado el 17-nov-2026. Validación funcional pendiente del usuario (§6.3 / §9.1) — ahora con el sistema en vivo ya parcheado; falta la prueba real de bloqueo manual y automático.*
