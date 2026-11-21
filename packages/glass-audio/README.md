# glass-audio

Control de volumen para Arch + Hyprland, clon de **pavucontrol** con UI estilo **Samsung One UI 8+** y **glassmorphism real**.

Parte de la familia de controles glass (junto con `glass-bt` y `glass-net`).

## Características

- **5 pestañas**: Salida, Entrada, Reproducción, Grabación, Configuración
- **Event-driven**: `subscribe` + ping, sin polling (0% CPU en reposo)
- **Glass real**: blur de Hyprland vía `gtk4-layer-shell`
- **Medidor VU en vivo**: streams monitor con `PEAK_DETECT` (~25 Hz)
- **Candado derivado**: el estado del candado se deriva de si los canales tienen el mismo volumen
- **Fórmulas correctas**: `dB = 60 × log10(vol/65536)` con tests unitarios
- **Español por defecto**, con i18n preparada

## Instalación

```bash
cd /home/c0o0c/JaKooLit/packages
cargo build --release -p glass-audio
```

Binario: `target/release/glass-audio`

## Uso

```bash
# Abrir con blur real (recomendado)
glass-audio --layer

# Modo daemon: precargar sin mostrar, toggle con kill -USR1
glass-audio --layer --hidden &
kill -USR1 $(pidof glass-audio)  # mostrar/ocultar

# Abrir pestaña específica
glass-audio --layer --tab=output
glass-audio --layer --tab=input
glass-audio --layer --tab=playback
glass-audio --layer --tab=record
glass-audio --layer --tab=config

# Expandir "Opciones avanzadas" en todas las tarjetas
glass-audio --layer --expand

# Dump del estado como JSON (diagnóstico)
glass-audio --dump
```

### Pestañas (`--tab`)

| Valor | Pestaña |
|-------|---------|
| `output` | Salida (sinks) |
| `input` | Entrada (sources) |
| `playback` | Reproducción (streams de apps) |
| `record` | Grabación (streams de captura) |
| `config` | Configuración (perfiles de tarjeta) |

## Integración con Hyprland

### Regla de capa (blur)

El namespace `audio-glass` debe estar en la lista de capas con blur en `~/.config/hypr/lua/rules.lua`:

```lua
local glass_layers = {
    -- ...
    "audio-glass",
    -- ...
}
for _, ns in ipairs(glass_layers) do
    hl.layer_rule({ match = { namespace = ns }, blur = true, ignore_alpha = 0.1 })
end
```

### Keybind

Ejemplo para `~/.config/hypr/lua/keybinds.lua`:

```lua
-- Centro de audio (toggle vía señal USR1, mismo patrón que glass-bt)
hl.bind({ "SUPER", "Volumedown", "exec", "pidof glass-audio >/dev/null 2>&1 || { setsid glass-audio --layer --hidden >/dev/null 2>&1 & sleep 0.3; }; kill -USR1 $(pidof glass-audio) 2>/dev/null || true" })
```

### Waybar (on-click)

El módulo `pulseaudio` de Waybar ya está configurado en `Modules` para abrir glass-audio:
- **Clic izquierdo**: `QsCenterToggle.sh audiocenter` (daemon con toggle USR1)
- **Clic derecho**: `glass-audio --layer` (ventana directa)

Si prefieres un módulo custom:

```json
{
    "name": "custom/audio",
    "format": "🔊",
    "on-click": "pidof glass-audio >/dev/null 2>&1 || { setsid glass-audio --layer --hidden >/dev/null 2>&1 & sleep 0.3; }; kill -USR1 $(pidof glass-audio) 2>/dev/null || true"
}
```

## Atajos de teclado

| Tecla | Acción |
|-------|--------|
| `Ctrl+Tab` | Cambiar pestaña |
| `Esc` | Ocultar ventana (daemon sigue vivo) |

## Arquitectura

- **`audio-core`**: Motor de audio con `libpulse-binding` threaded mainloop
- **`glass-theme`**: CSS compartido con tokens y widgets reutilizables
- **`glass-audio`**: UI GTK4 con layer shell para blur real

## Comandos soportados

| Acción | Descripción |
|--------|-------------|
| SetVolume | Volumen global (0–150%) |
| SetBalance | Balance L/R |
| SetChannelVolumes | Volumen por canal |
| SetMute | Silenciar |
| SetDefault | Marcar como predeterminado |
| SetPort | Cambiar puerto |
| MoveStream | Mover stream a otro dispositivo |
| SetCardProfile | Cambiar perfil de tarjeta |
| SetLatencyOffset | Ajustar latencia |

## Tests

```bash
cargo test -p audio-core
```

7 tests de fórmulas de volumen (dB ↔ porcentaje).

## Licencia

Mismo proyecto que JaKooLit dotfiles.
