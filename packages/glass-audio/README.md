# glass-audio

Mezclador de audio para Arch Linux/Hyprland, implementado en Rust + GTK4. Interfaz One UI 8.5: cristal translúcido, superficies flotantes, esquinas muy redondeadas y **barras de relleno** (sin perilla), con colores dinámicos de Matugen/Wallust a través de `glass-theme`.

## Incluye

- **Salida**: dispositivos, puertos, volumen, mute, predeterminado, canales y opciones avanzadas.
- **Entrada**: fuentes de audio reales con volumen, mute y selección predeterminada.
- **Reproducción** y **Grabación**: controles por stream/aplicación.
- **Configuración**: perfiles disponibles de cada tarjeta de sonido.
- Valores de volumen en porcentaje y dB; volumen máximo de 150%.
- Audio gestionado por el servicio `audio-core` (PipeWire/PulseAudio); sin dispositivos de muestra.
- Tema de vidrio con la paleta de wallpaper cargada por `glass-theme`.

## Compilar e instalar la versión actual

Desde la raíz del repositorio:

```bash
./install-scripts/glass-audio.sh
```

El script compila `packages/glass-audio` y reemplaza el ejecutable de usuario en `~/.local/bin/glass-audio`. Luego abre esa ruta explícitamente, evitando una versión antigua instalada en `/usr/local/bin`.

Para compilar sin instalar:

```bash
cd packages
cargo build --release -p glass-audio
cargo run --release -p glass-audio
```

Para imprimir el estado detectado como JSON: `glass-audio --dump`.

## Integración

- Clic en el icono de audio de Waybar: `~/.config/hypr/scripts/QsCenterToggle.sh audiocenter` → `~/.local/bin/glass-audio`.
- `SUPER + SHIFT + V`: abre `~/.local/bin/glass-audio`.
- `SUPER + V`: queda exclusivamente para QuickShell (`qs -c controlcenter ipc call panel toggle`).
- Las teclas multimedia (`XF86Audio*`) se gestionan con `~/.config/hypr/scripts/Volume.sh` (pamixer).

## Diseño

Lenguaje visual **One UI 8.5**, definido en `src/ui.css` y `src/ui.rs`:

- **Barras de relleno** (`fill_bar`): píldora de 52 px, relleno con gradiente sutil, sin perilla (solo una línea de 4×24 px como asa). El círculo de icono vive dentro de la barra y su clic alterna el mute; el `%` con cifras tabulares está a la derecha y los dB como texto secundario. Marca discreta en 100 % y cambio de tono de 100 % a 150 %. Las barras de canal usan la misma técnica en modo compacto.
- **Arrastre fluido**: envío limitado a ~50 ms, valor final tras 140 ms de calma. Mientras arrastra, `rebuild()` **no destruye widgets**: actualiza en sitio las demás barras con un guard `updating`, de modo que no hay parpadeos ni saltos. El foco de teclado se restaura tras el refresco; las flechas ajustan el volumen.
- **Pestañas**: activa con icono + texto, inactivas solo icono con tooltip; `Stack` con transición *crossfade* de 180 ms.
- **Panel y tarjetas**: panel radio 36 px, tarjetas flotantes radio 28 px separadas 10 px, borde `alpha(@color15, 0.14)`, brillo superior `inset` y sombras difusas.
- **Predeterminado**: chip único que une candado + check verde (`#4ade80`).
- **Controles**: desplegables píldora con popover de cristal; interruptores One UI para canales independientes, medidores y perfiles no disponibles. El VU es una línea fina de 3 px.
- **Colores**: únicamente variables del tema (`@surface`, `@on_surface`, `@primary`, `@on_primary`, `@outline_variant`, `@color15` y `alpha(...)`); se repintan al regenerar la paleta con Matugen/Wallust y se leen en tema claro y oscuro.
- **Blur**: GTK4 no tiene `backdrop-filter`; las superficies usan fondos con alpha y el desenfoque lo aplica Hyprland mediante reglas en `Hyprland-Dots/config/hypr/lua/rules.lua` (bloque «glass-audio: cristal translúcido», declarado después de la regla global `no_blur` para que prevalezca). La API Lua expone `no_blur` (no `blur`), así que se usa `no_blur = false` para reactivarlo. Los popovers de GTK4 se dibujan en la misma superficie y heredan el desenfoque.

La ventana arranca en 560×720 y es redimensionable (420–1040 px).
