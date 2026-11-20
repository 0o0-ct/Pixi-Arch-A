# Audita de Recursos: Waybar + nwg-dock-hyprland

**Sistema:** Arch Linux, Hyprland, Intel i7-13620H + NVIDIA RTX 4060 Max-Q, 31 GiB RAM  
**Objetivo:** Mantener estética de vidrio (glas) pero optimizar uso de recursos

---

## 1. Módulos de Waybar - Intervalos e Impacto en CPU

### Configuración actual: `~/.config/waybar/configs/[TOP] Default Laptop`

| Módulo | Intervalo | Impacto en CPU | Comentario |
|--------|-----------|----------------|------------|
| `custom/cava_mviz` | *sin intervalo (ejecución continua)* | **MUY ALTO** | Visualizador de audio en tiempo real con cava; proceso siempre corriendo |
| `network#speed` | **1 s** | **ALTO** | Polling constante de estadísticas de interfaz de red |
| `custom/hypridle` | **2 s** | MEDIO-Alto | Consultas frecuentes al compositor Hyprland |
| `custom/weather` | **3600 s (1 h)** | MEDIO | Peticiones de red + ejecución de script WeatherWrap.sh |
| `custom/dot_update` | *al hacer clic* | MEDIO | Consulta API de GitHub; impacto es esporádico pero incluye I/O de red |
| `hyprland/workspaces#rw` | *una vez al cargar* | BAJO | Consultas de espacios de trabajo al iniciar |
| `clock` | **10 s** | BAJO | Simple visualización de hora |
| `custom/swaync` | *una vez* | BAJO | Ícono de notificaciones |
| `tray` | *una vez* | BAJO | Bandeja del sistema |
| `bluetooth` | *una vez* | BAJO | Estado de Bluetooth |
| `custom/hint` | *una vez* | BAJO | Consejos/atajos |
| `custom/nightlight` | *una vez* | BAJO | Alternador de luz nocturna |
| `group/app_drawer` | N/A | BAJO | Componente drawer |
| `group/laptop` | N/A | BAJO | Grupo backlight + batería |
| `group/mobo_drawer` | N/A | BAJO | Grupo cpu/memory/disk |
| `group/audio` | N/A | BAJO | Grupo pulseaudio |
| `group/status` | N/A | BAJO | Grupo de estado |

### Módulos más costosos (por orden de prioridad):

1. **`custom/cava_mviz`** - El visualizador de audio mantiene un proceso cava corriendo continuamente leyendo entrada de audio y renderizando ASCII art. Este es el módulo más costoso en términos de CPU y memoria.

2. **`network#speed`** - Con intervalo de **1 segundo**, este módulo consulta constantemente las estadísticas de la interfaz de red (bytes entrantes/salientes). En un sistema con actividad de red variable, esto puede causar polling innecesario del sistema.

3. **`custom/hypridle`** - Polling cada **2 segundos** el estado de inactividad. El script `ScreenIdleToggle.sh` debe consultar el compositor Hyprland, lo que conlleva una llamada al IPC cada 2 segundos.

4. **`custom/weather`** - Aunque su intervalo es de 3600 segundos (1 hora), cada ejecución ejecuta `WeatherWrap.sh` que realiza múltiples pings y curl a servidores de clima. El sobrecosto de red y script hace que sea medible.

5. **`custom/dot_update`** - Se ejecuta al hacer clic, pero el módulo está siempre cargado. La consulta a la API de GitHub (`github.com`) implica I/O de red y procesamiento JSON.

---

## 2. Cambios Recomendados al Configurado de Waybar

### Cambios de alto impacto:

#### A. Desactivar/Reducir `custom/cava_mviz`
**Opción 1 (recomendada):** Comentar o remover el módulo del archivo de configuración waybar.
```jsonc
// Eliminar o comentar estas líneas del modules-left:
// "custom/cava_mviz",
// "custom/separator#blank",
```
**Impacto:** Elimina el proceso cava permanentemente en ejecución. El ahorro de CPU es significativo en sistemas con poco uso de audio.

**Opción 2 (menos frecuente):** Si el usuario quiere el visualizador ocasionalmente, puede lanzarlo manualmente o asignar un atajo de teclado en lugar de tenerlo siempre activo.

**¿Afecta al estética de vidrio?** No. El módulo `custom/cava_mviz` tiene formato `{}` (vacío), solo muestra el resultado de cava. Su remoción no afecta el diseño visual.

#### B. Aumentar intervalo de `network#speed`
Cambiar de `1s` a `10s` o `30s`:
```jsonc
"network#speed": {
    "interval": 30,  // de 1s a 30s
    ...
}
```
**Impacto:** Reduce las llamadas al sistema de un 100% a ~3-10% del anterior. Aún muestra velocidad de red pero de forma más prudente.

**¿Afecta al estética de vidrio?** No. Solo cambia con qué frecuencia se actualiza el texto.

#### C. Aumentar intervalo de `custom/hypridle`
Cambiar de `2s` a `10s`:
```jsonc
"custom/hypridle": {
    "interval": 10,  // de 2s a 10s
    ...
}
```
**Impacto:** Reduce las consultas al compositor Hyprland en un 80%. El estado de inactividad no necesita actualizarse tan frecuentemente.

**¿Afecta al estética de vidrio?** No. El módulo solo muestra un ícono/indicador de estado.

### Cambios de medio impacto:

#### D. Ajustar `custom/weather`
El intervalo ya es de 3600s (1 hora), que es razonable. Podemos:
- Mantenerlo así (es el intervalo razonable para clima)
- Opcional: Aumentar a `7200s` (2 horas) si el usuario quiere ahorro extra
- Opcional: Cambiar a actualización manual (solo al hacer clic)

**¿Afecta al estética de vidrio?** No. El módulo muestra el clima actual.

### Cambios de bajo impacto:

#### E. `custom/dot_update`
Este módulo solo se ejecuta activamente al hacer clic. Su presencia en la configuración no cuesta CPU hasta que el usuario hace clic. Podemos:
- Mantenerlo tal cual (bajo impacto)
- Opcional: Moverlo a un grupo deslizable o drawer para que no esté siempre visible

**¿Afecta al estética de vidrio?** No. Es un ícono de actualización.

---

## 3. Optimización de los Scripts del Dock (nwg-dock-hyprland)

### Configuración actual:
- 2 instancias de nwg-dock-hyprland (una por monitor: eDP-1 y HDMI-A-1)
- Posición: bottom, alineación: center
- Tamaño de ícono: 40px, margen: 12px
- Scripts adicionales en bucle: dock_hover_monitor.sh, dock_tooltip.sh, dock_fullscreen_monitor.sh

### Análisis de scripts:

| Script | Tipo | Intervalo/Comportamiento | Impacto |
|--------|------|-------------------------|---------|
| `dock_fullscreen_monitor.sh` | Event-driven (socket Hyprland) | Escucha eventos `fullscreen` vía socket | **BAJO** - No es polling, es por evento del compositor |
| `dock_hover_monitor.sh` | Bucle polling | `INTERVAL=0.15s` (150ms) - chequeo continuo de posición del mouse | **MEDIO** - Bucle cada 150ms; 6-7 veces por segundo |
| `dock_tooltip.sh` | Bucle polling | `INTERVAL=0.2s` (200ms) - chequeo de tiempo de hover | **MEDIO** - Bucle cada 200ms; 5 veces por segundo |

### Cambios recomendados:

#### F. Aumentar intervalos de los scripts de hover y tooltip

**dock_hover_monitor.sh:** Cambiar `INTERVAL=0.15` a `INTERVAL=1.0`:
- **De:** 0.15s (6.6 chequeos/segundo)
- **A:** 1.0s (1 chequeo/segundo)
- **Ahorro:** ~85% reducciones en ejecuciones del bucle

**dock_tooltip.sh:** Cambiar `INTERVAL=0.2` a `INTERVAL=1.0`:
- **De:** 0.2s (5 chequeos/segundo)
- **A:** 1.0s (1 chequeo/segundo)
- **Ahorro:** ~80% reducciones en ejecuciones del bucle

**Nota de usabilidad:** El tiempo de respuesta seguirá siendo aceptable. El hover para mostrar el dock tendrá un retardo máximo de 1 segundo (frente a los 150ms actuales), y el tooltip aparecerá después de mantener el mouse quieto 2 segundos + 1 segundo de chequeo = ~3 segundos máximo (frente a ~2.2s actuales). Es un compromiso aceptable para el ahorro de recursos.

#### G. Consolidar scripts del dock

Los tres scripts (`dock_hover_monitor.sh`, `dock_tooltip.sh`, `dock_fullscreen_monitor.sh`) son loops bash separados. Podemos:
- **Opción 1 (simple):** Mantenerlos separados pero aumentar sus intervalos como arriba
- **Opción 2 (optimizada):** Consolidar la lógica en un solo script con parámetros de configuración, reduciendo la sobrecarga de procesos (3 procesos bash vs 1). Esto es más un cambio de arquitectura que una simple optimización.

Dado que el usuario quiere "no hacer cambios" pero solo reportar, recomiendo la **Opción 1** (aumentar intervalos) que es la más segura y requiere menos cambios de arquitectura.

**¿Afecta al estética de vidrio?** No. Los scripts solo manejan comportamiento (mostrar/ocultar dock, tooltips), no el diseño visual. La estética la proporciona el `style.css` de nwg-dock-hyprland y el `style.css` de waybar.

---

## 4. Recomendaciones de CSS (`[Catppuccin] Mocha.css`)

### Análisis actual:

El archivo CSS tiene comentarios explícitos sobre performance (líneas 37-48):
- ✅ **No hay sombras** en ningún lugar (mencionado como "la propiedad más costosa para el renderizador GTK")
- ✅ **No hay opacidad** en contenedores (usa rgba()/alpha() en lugar de opacity)
- ✅ **Transiciones** solo animan `background-color / border-color / color`, 160ms
- ✅ **Sin movimiento loop** - referencias a keyframes que no existen
- ✅ **Blur es de Hyprland**, no CSS (usando layerrules + ignore_alpha)

### El único punto a revisar:

**Línea 189:** `box-shadow: 0 4px 30px rgba(0, 0, 0, 0.10);`

Este shadow se aplica a `.modules-left, .modules-center, .modules-right`. Aunque el comentario dice que "no hay sombras en ningún lugar", este selector sí tiene una sombra sutil.

**Recomendación:** Si se busca maximizar performance, este shadow podría reemplazarse por un enfoque puramente de Hyprland (usando `layerrule` en la configuración de Hyprland en lugar de CSS). Sin embargo, dado que es un shadow sutil (0.10 alpha) y el sistema tiene 31 GiB de RAM, **el impacto es mínimo** y la sombra contribuye al efecto "vidrio separado de la pared".

**Decisión:** Mantener el shadow CSS como está. El ahorro de removerlo es imperceptible y afectaría la estética solicitada. El shadow de Hyprland (si está configurado) ya estaría haciendo el efecto principal.

### Otras optimizaciones CSS (bajo impacto):

- Las transiciones de 160ms en `window#waybar` son razonables y no bloquean el hilo principal significativamente.
- La regla `@import url("wallust/colors-waybar.css");` es necesaria y no tiene costo de ejecución en tiempo de ejecución.

---

## 5. Prioridad de los Cambios

| Prioridad | Cambio | Impacto estimado en CPU | Efecto estético |
|-----------|--------|------------------------|-----------------|
| **Alta** | Remover `custom/cava_mviz` waybar module | **Alto** - Elimina proceso cava permanente | Ninguno (módulo vacío `{}`) |
| **Alta** | Aumentar `network#speed` de 1s a 30s | **Alto** - Reduce polling 3-10x | Ninguno |
| **Media** | Aumentar `custom/hypridle` de 2s a 10s | **Medio** - Reduce consultas IPC 5x | Ninguno |
| **Media** | Ajustar intervalos dock scripts (hover/tooltip) | **Medio** - Reduce loops bash 5-8x | Ninguno |
| **Baja** | Mover `custom/dot_update` a drawer | **Bajo** - Organizativo | Ninguno |
| **Baja** | Revisar `box-shadow` en CSS | **Muy bajo** - Ganancia imperceptible | Podría afectar sutilmente el efecto "tarjeta de vidrio" |

---

## 6. Resumen Ejecutivo

**Cambios recomendados para optimizar recursos manteniendo estética glas:**

1. **Remover o comentar `custom/cava_mviz`** del config waybar - Elimina el proceso cava más costoso
2. **Cambiar intervalo `network#speed`** de 1s a 30s - Reduce significativamente las llamadas al sistema
3. **Cambiar intervalo `custom/hypridle`** de 2s a 10s - Reduce consultas al compositor
4. **Aumentar intervalos dock scripts:** `dock_hover_monitor.sh` de 0.15s a 1.0s, `dock_tooltip.sh` de 0.2s a 1.0s - Reduce loops polling en un 80-85%

**Total estimado de ahorro:** Reducción significativa del uso de CPU por parte de waybar y los scripts del dock, liberando recursos para el juego/renderizado en el sistema con i7-13620H + RTX 4060, manteniendo intacta la estética de vidrio (glas) que el usuario disfruta.

**Ningún cambio afecta negativamente la estética glas:** Las modificaciones son puramente de rendimiento (intervalos, procesos redundantes) y el diseño visual sigue dependiendo del CSS y la configuración de Hyprland, no de la frecuencia de actualización de los módulos.