# 💫 Glass Bluetooth (`glass-bt`)

Un gestor de Bluetooth nativo, ultrarrápido y minimalista para **Arch Linux** con **Hyprland (Wayland)**, escrito en **Rust** con arquitectura asíncrona (`bluer` + `tokio`) e interfaz **GTK4 + Layer Shell** con estética *frosted glassmorphism* inspirada en macOS Tahoe y One UI.

---

## ✨ Características

- **Rendimiento extremo:** Binario nativo de ~4.9 MB, arranque en menos de 10 ms y consumo inferior a 25 MB de RAM.
- **Sin Libadwaita:** Estilizado 100% mediante CSS con fondos translúcidos, bordes especulares de luz y radios de curvatura coordinados con la paleta de Wallust.
- **Integración con Hyprland Layer-Shell:**
  - Anclado dinámicamente arriba a la derecha (`Edge::Top`, `Edge::Right`).
  - Modo de teclado `OnDemand`: pulsar <kbd>Esc</kbd> cierra instantáneamente la ventana.
  - Namespace `bt-glass` listo para desenfoque real (*blur*) de Hyprland.
- **BlueZ en tiempo real (sin polling):** Escucha eventos de D-Bus de adaptadores y dispositivos para reflejar conexiones, nivel de batería, RSSI y desconexiones en vivo.
- **Emparejamiento interactivo:** Agente D-Bus propio con diálogo de confirmación de PIN/Passkey.
- **Acciones rápidas:** Conectar, desconectar, alternar escaneo, encendido/apagado y olvidar dispositivo con un solo clic.

---

## 🛠 Requisitos en Arch Linux

```bash
sudo pacman -S --needed gtk4 gtk4-layer-shell bluez bluez-utils rust cargo
```

---

## 🚀 Compilación e Instalación

### Compilación local
```bash
cd ~/Proyectos/glass-bt
cargo build --release
```

### Instalar en el sistema
```bash
sudo install -Dm755 target/release/glass-bt /usr/local/bin/glass-bt
```

O mediante `makepkg` usando el `PKGBUILD`:
```bash
makepkg -si
```

---

## ⚙️ Configuración para Hyprland

### 1. Regla de capa para desenfoque real (Frosted Glass)

En tu configuración de Hyprland 0.57+ en Lua (`~/.config/hypr/lua/rules.lua`):

```lua
hl.layer_rule({ match = { namespace = "bt-glass" }, blur = true, ignore_alpha = 0.1 })
```

*(Si utilizas sintaxis hyprlang clásica en `WindowRules.conf`)*:
```ini
layerrule = match:namespace bt-glass, blur on
layerrule = match:namespace bt-glass, ignore_alpha 0.1
```

### 2. Atajo de teclado (Keybind)

En `~/.config/hypr/lua/keybinds.lua`:
```lua
hl.bind("SUPER + ALT, B", "exec", "glass-bt")
```

O para toggle inteligente (abrir si está cerrado, cerrar si está abierto):
```lua
hl.bind("SUPER + ALT, B", "exec", "pidof glass-bt && killall glass-bt || glass-bt")
```

### 3. Integración con Waybar

En `~/.config/waybar/Modules`:
```json
"bluetooth": {
    "format": " {status}",
    "format-disabled": "󰂲",
    "format-connected": "󰂱 {device_alias}",
    "on-click": "pidof glass-bt && killall glass-bt || glass-bt",
    "tooltip-format": "{controller_alias}\t{controller_address}"
}
```

---

## 📁 Estructura del Código

```
glass-bt/
├── Cargo.toml
├── PKGBUILD
├── README.md
└── src/
    ├── main.rs                 # Inicializa runtime Tokio y loop GTK4
    ├── events.rs               # Protocolo BtCommand y BtEvent
    ├── bluetooth/              # Capa BlueZ asíncrona
    │   ├── mod.rs              # Servicio de adaptador y streams de eventos
    │   └── agent.rs            # Agente D-Bus de emparejamiento interactivo
    └── ui/                     # Capa de presentación GTK4
        ├── mod.rs              # Carga CSS y puente de eventos glib
        ├── style.css           # Estilos Frosted Glass & One UI
        ├── window.rs           # Ventana Layer-Shell y listas de dispositivos
        ├── header.rs           # Interruptor iOS y botón de escaneo
        ├── device_row.rs       # Tarjeta individual de dispositivo
        └── pairing_dialog.rs   # Diálogo modal de confirmación PIN
```

