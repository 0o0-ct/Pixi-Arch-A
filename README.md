# 󰣇  Pixi-Arch-A

<div align="center">

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-85A5FF?style=for-the-badge&logo=hyprland&logoColor=white)
![Theme](https://img.shields.io/badge/Aesthetics-Frosted%20Glass-FF4136?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Zsh%20%2B%20OhMyZsh-4BF?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Version](https://img.shields.io/badge/Version-v1.0.0--Antigravity-white?style=for-the-badge)

<p align="center">
  <img src="https://raw.githubusercontent.com/0o0-ct/Pixi-Arch/main/Hyprland-Dots/assets/latte.png" width="450" style="border-radius: 12px; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.4);" />
</p>

### 💫 Un entorno de escritorio ultra-premium de cristal esmerilado impulsado por Hyprland y Arch Linux 💫

---

</div>

> [!IMPORTANT]
> **Pixi-Arch-A** es una evolución y ramificación personalizada de alto rendimiento diseñada para ofrecer una experiencia estética fuera de serie. Combina la velocidad de Arch Linux con el dinamismo del compositor Hyprland, fusionando un diseño de **Cristal Esmerilado (Frosted Glassmorphism)** coherente con colores oscuros e iluminación carmesí.

---

## ✨ Características Premium Exclusivas

### 1. 🔮 Motor de Cristal Esmerilado (Frosted Glassmorphism)
Hemos rediseñado por completo el compositor para crear un efecto de vidrio real tridimensional, denso y texturizado a lo largo de todo tu sistema:
* **Desenfoque Denso y Granulado:** Configurado con `passes = 4` y `size = 10` para una difuminación de calidad cinematográfica, junto a un grano sutil de `noise = 0.03`, contraste de `1.15`, brillo de `0.82` y vibración de `0.3` en [UserDecorations.conf](file:///.config/hypr/UserConfigs/UserDecorations.conf).
* **Transparencia en Capas Altas (ignore_alpha 0.1):** Rediseñamos el filtro alfa de Hyprland para permitir el desenfoque en fondos con baja opacidad. Componentes como **Waybar**, **Rofi**, **SwayNC** y las **Notificaciones** flotan ahora como placas de cristal esmerilado traslúcido sin perder legibilidad.
* **Translucidez Inteligente de Ventanas:** Opacidad global optimizada al `86%` para ventanas activas y al `78%` para inactivas, creando un hermoso apilamiento visual.

### 2. 🗁 Thunar Estilo "Ultra-Glass" con Bordes Brillantes
El gestor de archivos Thunar se ha transformado en la joya de la corona del sistema:
* **Efecto Vidrio Puro:** Opacidad específica del `80%` (activa) y `70%` (inactiva) para fundirse de forma espectacular sobre cualquier fondo de pantalla.
* **Borde Fino de Cristal:** Configurado con un borde ultra-delgado de `border_size = 1` y un gradiente de color blanco semi-transparente (`rgba(ffffff66)` y `rgba(ffffff1a)`) que brilla sutilmente al enfocar la ventana en [WindowRules.conf](file:///.config/hypr/UserConfigs/WindowRules.conf).

### 3. 🎨 Estética Cohesiva "Tela Red-Dark"
* **Iconografía Premium:** Implementación a nivel de sistema del paquete de iconos premium `Tela-red-dark` de vinceliuice para una combinación perfecta con tonos oscuros y detalles en rojo carmesí.
* **Integración GTK y Aplicaciones:** Sincronización completa en GTK 3/4, Rofi, Waybar y SwayNC para mantener un lenguaje visual oscuro y unificado.

### 4. 󰣇 Fastfetch Adaptativo "Pixi-Arch-A" (Con Inicial del Creador)
El comando de bienvenida en la terminal es completamente interactivo y lleva la marca de nuestro equipo:
* **Letras Sans-Serif Bold:** Diseñado con caracteres matemáticos estilizados de alta intensidad (`𝗣𝗶𝘅𝗶-𝗔𝗿𝗰𝗵-𝗔`) para un impacto visual nítido sobre fondos transparentes.
* **Diseño Adaptativo en Tiempo Real (.zshrc):** El inicio de la shell mide dinámicamente el ancho de tu terminal:
  * **Menos de 100 columnas:** Carga automáticamente un diseño compacto superior con el logotipo micro oficial de Arch Linux (`arch_small`).
  * **100 columnas o más:** Carga el diseño de pantalla completa con el logotipo estándar lateral de Arch Linux (`arch`).
* **Utilidad de Cambio de Color Integrada:** Ejecuta el comando de alternancia [`toggle-color-gradient.py`](file:///.config/fastfetch/toggle-color-gradient.py) para cambiar instantáneamente la paleta de colores del logotipo y título entre **Súper Blanco Brillante** (por defecto) y el **Gradiente Cian Oficial de Arch** en un solo clic.

---

## 🛠️ Atajos de Teclado Clave y Uso

* **Bloqueo del Sistema instantáneo:** Presiona **`SUPER + L`** para bloquear tu pantalla con un efecto de desenfoque e información en tiempo real a través de `hyprlock` y `hypridle`.
* **Lanzador de Aplicaciones Rofi:** Presiona **`SUPER + D`** para abrir un menú flotante de cristal esmerilado que se adapta de forma inteligente a la paleta de colores de tu fondo.
* **Abrir Terminal Kitty:** Presiona **`SUPER + Enter`** para desplegar terminales traslúcidas que se superponen estéticamente como hojas de vidrio.
* **Alternar Paleta del Logo de Terminal:** Ejecuta:
  ```bash
  ~/.config/fastfetch/toggle-color-gradient.py
  ```

---

## ⚙️ Gestión de Bloqueo e Inactividad (Timeout)
Toda la inactividad de tu pantalla se gestiona de forma centralizada en [`hypridle.conf`](file:///.config/hypr/hypridle.conf):
* **Aviso de inactividad:** A los **9 minutos** (`timeout = 540`) recibirás una notificación de aviso en el sistema.
* **Bloqueo de seguridad:** A los **10 minutos** (`timeout = 600`) el sistema bloqueará la sesión automáticamente mediante el comando `loginctl lock-session`, el cual ejecuta el protector de pantalla seguro `hyprlock`.

---

## 📥 Clonación y Sincronización del Proyecto
Este sistema está completamente enlazado a tu repositorio personal en GitHub. Para sincronizar tus personalizaciones y actualizaciones futuras:

```bash
# Clonar tu repositorio oficial
git clone https://github.com/0o0-ct/Pixi-Arch.git ~/Pixi-Arch-A

# Empujar nuevos cambios y actualizaciones
git add .
git commit -m "feat: descripción de mis mejoras"
git push origin main
```

---

<div align="center">

## 🤝 Créditos y Agradecimiento Original

> [!NOTE]
> **Reconocimiento:** Este proyecto es un fork y personalización profunda basada en el excelente instalador y dotfiles de **JaKooLit** ([Arch-Hyprland](https://github.com/JaKooLit/Arch-Hyprland)). Agradecemos enormemente la gran base, la arquitectura del script y la inspiración original que nos ha permitido construir este entorno de escritorio único y adaptado.

</div>
