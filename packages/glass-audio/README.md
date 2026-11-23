# glass-audio

Mezclador de audio para Arch Linux/Hyprland, implementado en Rust + GTK4. La interfaz toma como referencia la maqueta HTML del usuario: tarjetas amplias, pestañas segmentadas y controles de volumen en píldora, con transparencias y colores dinámicos de Matugen/Wallust a través de `glass-theme`.

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
- `volume-control` permanece disponible como ejecutable manual, sin reasignar `SUPER + V`.
