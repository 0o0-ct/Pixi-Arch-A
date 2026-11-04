# Migración a Hyprland 0.57+ (Lua)

> **Fecha:** 02-nov-2026 | **Estado:** ✅ COMPLETADA | **Rama:** `feat/hyprland-lua-migration-2`

---

## Resumen

Esta migración transforma la configuración de Hyprland de **hyprlang (.conf)** a **Lua**, la nueva forma de configurar Hyprland a partir de la versión **0.57**.

### Cambios principales

| Aspecto | Antes (0.56 y anteriores) | Después (0.57+) |
|---|---|---|
| Configuración | `hyprland.conf` (hyprlang/sintaxis key=value) | `hyprland.lua` (Lua API) |
| Estructuración | Archivos monopliciajes | Módulos Lua en `config/hypr/lua/` |
| Claves de enlace | `bind = mod, key, dispatcher, cmd` | `hl.bind("mod + key", dispatcher)` |
| Reglas de ventana | `windowrule = match:class, opts` | `hl.window_rule({ match = { class = "..." }, ... })` |
| Variables de entorno | `env = key, value` | `hl.env({ key = "value" })` |
| Autostart | `exec-once = cmd` | `hl.on("hyprland.start", ...)` |
| Decoraciones | `decoration { blur = ... }` | `hl.config({ decoration = { ... } })` |

---

## Estructura de la configuración

```
Hyprland-Dots/config/hypr/
├── hyprland.lua             # ── Punto de entrada principal (requiere los módulos)
└── lua/                     # ── Módulos Lua (carga modular)
    ├── monitors.lua         # Monitores y resoluciones
    ├── env.lua              # Variables de entorno
    ├── autostart.lua        # Autostart / scripts de arranque
    ├── settings.lua         # Opciones generales (input, general, misc, etc.)
    ├── decorations.lua      # Decoraciones de ventanas (blur, sombras, etc.)
    ├── animations.lua       # Animaciones y curvas personalizadas
    ├── keybinds.lua         # Atajos de teclado y ratón (binding nativo)
    ├── rules.lua            # Reglas de ventanas (size, layer, float, etc.)
    └── colors.lua           # Paleta de colores (generada por Wallust/matugen)

Hyprland-Dots-Old/           # ── Carpeta de respaldo con todos los archivos .conf originales
├── config/
│   └── hypr/
│       ├── hyprland.conf
│       ├── hypridle.conf
│       ├── hyprlock-*.conf
│       ├── configs/
│       ├── animations/
│       ├── UserConfigs/
│       ├── Monitor_Profiles/
│       ├── wallust/
│       └── wallpaper_effects/
└── *.hl (archivos de experimentación Lua bajo prueba)
```

---

## Migración de módulos clave

### 1. Monitores (`monitors.lua`)

- La configuración de monitores se mantiene en `$HOME/.config/hypr/monitors.conf` (tradicionalmente)
- Se carga vía `hl.config({})` para mantener la compatibilidad
- Las resoluciones y posiciones se gestionan con `hl.monitor()`

### 2. Variables de entorno (`env.lua`)

**En .conf:**
```
env = HOME, /home/user
env = LANGUAGE, es_ES
```

**En Lua:**
```lua
hl.env({
    HOME = "/home/user",
    LANGUAGE = "es_ES"
})
```

---

### 3. Autostart (`autostart.lua`)

**En .conf:**
```
exec-once = $HOME/.config/hypr/scripts/StartupMenu.sh
```

**En Lua:**
```lua
hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.config/hypr/scripts/StartupMenu.sh")
end)
```

---

### 4. Configuración general (`settings.lua`)

**En .conf:**
```
gaps_in = 4
gaps_out = 8
border_size = 2
layout = dwindle
```

**En Lua:**
```lua
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle"
    }
})
```

---

### 5. Decoraciones (`decorations.lua`)

**En .conf:**
```
blur = 8
blur:active = 8
blur:inactive = 6
shadow = 12 4 16 #00000088
```

**En Lua:**
```lua
hl.config({
    decoration = {
        blur = { size = 8, pass = 1, alpha = 0.06 },
        shadow = { size = 12, h_offset = 0, v_offset = 4, blur = 16, color = "#00000088" },
        active_window_border = { size = 2, color = "#FF4136FF", style = "solid" },
    }
})
```

---

### 6. Atajos de teclado (`keybinds.lua`)

**En .conf:**
```
bind = SUPER, Return, exec, $HOME/.config/hypr/scripts/KittyRotate.sh
bind = SUPER, D, exec, pkill rofi || true && rofi -show drun
```

**En Lua:**
```lua
local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts or {})
end

bind("SUPER + Return", exec(terminal), { description = "abrir terminal" })
bind("SUPER + D", exec("pkill rofi || true && rofi -show drun"), { description = "lanzador de aplicaciones" })
```

### 7. Reglas de ventanas (`rules.lua`)

**En .conf:**
```
windowrule = match:class ^(jetbrains-studio.*)$, float on, center on
windowrule = match:class ^(kitty)$, layer top
```

**En Lua:**
```lua
hl.window_rule({ match = { class = "jetbrains-studio" }, float = true, center = true })
hl.window_rule({ match = { class = "kitty" }, layer = "top", float = false })
```

---

## Archivos eliminados o movidos

| Archivo | Nuevo destino |
|---|---|
| `config/hypr/hyprland.conf` | `Hyprland-Dots-Old/config/hypr/hyprland.conf` |
| `config/hypr/hypridle.conf` | `Hyprland-Dots-Old/config/hypr/hypridle.conf` |
| `config/hypr/hyprlock-*.conf` | `Hyprland-Dots-Old/config/hypr/hyprlock-*.conf` |
| `config/hypr/monitors.conf` | `Hyprland-Dots-Old/config/hypr/monitors.conf` |
| `config/hypr/workspaces.conf` | `Hyprland-Dots-Old/config/hypr/workspaces.conf` |
| `config/hypr/configs/*.conf` | `Hyprland-Dots-Old/config/hypr/configs/*.conf` |
| `config/hypr/animations/*.conf` | `Hyprland-Dots-Old/config/hypr/animations/*.conf` |
| `config/hypr/UserConfigs/*.conf` | `Hyprland-Dots-Old/config/hypr/UserConfigs/*.conf` |
| `config/hypr/wallust/*.conf` | `Hyprland-Dots-Old/config/hypr/wallust/*.conf` |
| `config/hypr/wallpaper_effects/*` | `Hyprland-Dots-Old/config/hypr/wallpaper_effects/*` |
| `config/hypr/hyprland.hl`, `*.hl` | `Hyprland-Dots-Old/config/hypr/*.hl` |

---

## Actualización del instalador (`install.sh`)

- Referencias a `SystemSettings.conf` eliminadas
- La configuración de teclado ahora se verifica vía la estructura Lua

---

## Redes de compatibilidad

- Los archivos originales siguen intactos en `Hyprland-Dots-Old/` para auditoría
- AGSColors (AGS widgets) funcionan con el nuevo sistema Lua
- Matugen sigue generando paletas con la misma plantilla `ags.scss`
- QuickShell, swaync, wlogout, etc. siguen funcionando sin cambios

---

## Recursos

- [Hyprland Wiki (Configuring)](https://wiki.hypr.land/configuring/)
- [PR de migración original](https://github.com/0o0-ct/Pixi-Arch-A/commits?author=0o0-ct)
- [Hyprland 0.57 release notes](https://hypr.land/news/update57)
