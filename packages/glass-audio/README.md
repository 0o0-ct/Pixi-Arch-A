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

## Compilar y ejecutar

```bash
cd packages
cargo build --release -p glass-audio
cargo run --release -p glass-audio
```

Para imprimir el estado detectado como JSON: `glass-audio --dump`.

## Atajo de Hyprland

`SUPER + SHIFT + V` abre glass-audio. `SUPER + V` queda reservado para `volume-control`.

La ventana admite el desenfoque de Hyprland con namespace `audio-glass` (añádelo a las reglas de capa de tu configuración si corresponde).
