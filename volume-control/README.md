# Control de Volumen - Pixi-Arch-A

Control de volumen moderno en Rust + Iced, adaptado a la paleta de colores del sistema (qml_color.json).

## Características

- **GUI moderna** con slider de volumen y botones de mute/silenciar
- **Colores adaptados** a la paleta de qml_color.json (rosa/magenta oscuro)
- **CLI completo** compatible con las keybinds de Hyprland
- **PipeWire/PulseAudio** via pamixer
- **Reemplaza** la notificación vieja de swaync por una ventana elegante

## Colores del tema

| Elemento | Color |
|---|---|
| Fondo | `#191114` |
| Texto principal | `#eedfe2` |
| Acento principal | `#ffb0cc` |
| Acento secundario | `#f0bc95` |
| Borde | `#514347` |
| Capa 1 | `#31282a` |
| Capa 2 | `#261d20` |

## Compilación

```bash
cd /home/c0o0c/JaKooLit/volume-control
cargo build --release
```

## Instalación

```bash
bash /home/c0o0c/JaKooLit/install-volume-control.sh
```

## Uso

### GUI

```bash
volume-control          # Abre la ventana de control de volumen
```

### CLI

```bash
volume-control --get            # Imprime el volumen actual
volume-control --inc            # Sube el volumen 5%
volume-control --dec            # Baja el volumen 5%
volume-control --inc-precise    # Sube el volumen 1%
volume-control --dec-precise    # Baja el volumen 1%
volume-control --toggle         # Silencia/desilencia
volume-control --toggle-mic     # Silencia/desilencia el micrófono
volume-control --get-icon       # Imprime el icono correspondiente
```

## Keybinds de Hyprland

Las keybinds están configuradas en `Hyprland-Dots/config/hypr/lua/keybinds.lua`:

| Tecla | Acción |
|---|---|
| `XF86AudioRaiseVolume` | Subir volumen 5% |
| `XF86AudioLowerVolume` | Bajar volumen 5% |
| `ALT + XF86AudioRaiseVolume` | Subir volumen 1% |
| `ALT + XF86AudioLowerVolume` | Bajar volumen 1% |
| `XF86AudioMicMute` | Silenciar micrófono |
| `XF86AudioMute` | Silenciar audio |
| `SUPER + V` | Abrir GUI de control de volumen |

## Dependencias

- Rust 1.80+ (cargo)
- pamixer
- PipeWire o PulseAudio

## Estructura del proyecto

```
volume-control/
├── Cargo.toml
├── src/
│   └── main.rs
└── target/
    └── release/
        └── volume-control
```

## Licencia

MIT - Pixi-Arch-A
