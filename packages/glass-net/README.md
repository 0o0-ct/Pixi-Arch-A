# glass-net — Gestor de Red Glassmorphism nativo (Rust + GTK4)

Gestor de red **Wi-Fi / Ethernet / VPN** nativo para Hyprland, hermano de
[glass-bt](../glass-bt). Habla directamente con **NetworkManager** por D-Bus
(`org.freedesktop.NetworkManager` vía zbus), sin nm-applet ni blúeman.

Reemplaza al applet GTK de NetworkManager con un panel flotante de vidrio
tintado con los colores del wallpaper (Wallust / Matugen) y recarga los
colores en caliente al cambiar el fondo.

## Características

- 🔍 **Escaneo automático** al abrir + refresco periódico cada ~12 s
- 📶 **Barras de señal** estilo One UI, candado y etiqueta de seguridad (WPA/WPA2/WPA3/WEP)
- 🔗 **Conectar / Desconectar / Olvidar** redes Wi-Fi; diálogo de contraseña con
  toggle de visibilidad (soporta WPA-PSK y SAE/WPA3)
- 🔌 **Red cableada**: estado + IP + conectar/desconectar
- 🛡️ **VPN**: listar perfiles, conectar/desactivar
- 🎨 **Temado dinámico**: lee `~/.config/waybar/wallust/colors-waybar.css` y
  hot-reload al cambiar wallpaper (mismo mecanismo que glass-bt)
- 🖱️ Arrastrable desde el título (WindowHandle), Esc o ✕ para cerrar
- 🪟 Modo `--layer` opcional (gtk4-layer-shell, namespace `net-glass`)

## Modo daemon (apertura instantánea)

glass-net corre como daemon precargado, igual que glass-bt v0.2.0:

- Autostart (`~/.config/autostart/glass-net.desktop`) lanza `glass-net --hidden`
  al iniciar sesión (sin ventana, sin escaneos periódicos: cero consumo oculto).
- Click / keybind / botón rápido envía `SIGUSR1`:
  `kill -USR1 $(pidof glass-net)` → muestra u oculta en ~30 ms, con las redes
  ya escaneadas.
- Esc o ✕ ocultan la ventana; `killall glass-net` termina el daemon.

## Compilación

```sh
# Dependencias (Arch): sudo pacman -S gtk4 gtk4-layer-shell networkmanager rust cargo
cargo build --release
sudo install -Dm755 target/release/glass-net /usr/local/bin/glass-net
```

O con el PKGBUILD: `makepkg -si`.

## Integración en Pixi-Arch-A

- **Waybar** (`Modules`): `network` y `network#speed` con
  `on-click: pidof glass-net >/dev/null 2>&1 || { setsid glass-net --hidden & sleep 0.3; }; kill -USR1 $(pidof glass-net) 2>/dev/null || true`
- **QsCenterToggle.sh**: `netcenter` delega a glass-net (como btcenter → glass-bt)
- **Hyprland** (`rules.lua`): regla de capa `net-glass` (blur) y regla de ventana
  float 460x640 centrada para las clases `glass-net` / `com.pixi.glassnet`
- **Keybind**: `SUPER + SHIFT + N`
- **nm-applet**: autostart deshabilitado (el paquete se conserva por
  nm-connection-editor como editor avanzado)

## Estructura del código

```
src/
├── main.rs            # Canales Tokio <-> GTK4, hilo worker dedicado
├── events.rs          # Protocolo NetCommand / NetEvent (molde BtCommand de glass-bt)
├── network/
│   └── mod.rs         # Backend NetworkManager (zbus): refresco con diff de
│                      # estado cada 2 s, escaneos, conexiones, VPN
└── ui/
    ├── mod.rs         # GtkApplication + CSS dinámico + 3 FileMonitors hot-reload
    ├── window.rs      # Panel glass: Conexión actual / Redes / Cableada / VPN
    ├── header.rs      # Squircle Wi-Fi + título + rescan + switch iOS + cerrar
    ├── network_row.rs # Tarjetas de AP / Ethernet / VPN
    ├── password_dialog.rs # Modal de contraseña con ojo Lucide
    ├── icons.rs       # Render y recolor de SVG Lucide
    ├── style.css      # Glassmorphism + tokens wallust
    └── icons/         # SVG Lucide embebidos
```
