# 󰣇  Pixi-Arch-A

> [!IMPORTANT]
> **Pixi-Arch-A** es una evolución y ramificación personalizada de alto rendimiento diseñada para ofrecer una experiencia estética fuera de serie. Combina la velocidad de Arch Linux con el dinamismo del compositor Hyprland, fusionando un diseño de **Cristal Esmerilado (Frosted Glassmorphism)** coherente con colores oscuros e iluminación carmesí.
>
> Este proyecto ha sido creado y pulido con amor por su creador junto a su asistente de IA **Antigravity** para ofrecer una experiencia hispanohablante única, fluida y con un diseño visual insuperable.

---

<div align="center">

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-85A5FF?style=for-the-badge&logo=hyprland&logoColor=white)
![Theme](https://img.shields.io/badge/Aesthetics-Frosted%20Glass-FF4136?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Zsh%20%2B%20OhMyZsh-4BF?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Version](https://img.shields.io/badge/Version-v1.0.0--Antigravity-white?style=for-the-badge)

### 💫 Un entorno de escritorio ultra-premium de cristal esmerilado impulsado por Hyprland y Arch Linux 💫

<p align="center">
  <img src="./Hyprland-Dots/assets/screenshot.jpg" width="100%" style="border-radius: 12px; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.6);" />
  <br>
  <sub><b>[Pixi-Arch-A - Súper Glass & Carmesí Oscuro]</b></sub>
</p>

</div>

> [!TIP]
> **🎨 Ciclador de Temas Dark Glass Integrado:** ¡Olvídate de los fondos claros y aburridos! **Pixi-Arch-A** está blindado al 100% en Modo Oscuro. Haz clic en el botón de la paleta (`󰏘 `) en tu barra superior para ciclar fondos oscuros aleatorios y regenerar de forma instantánea todo tu tema de cristal translúcido con **Wallust** de forma totalmente automática y cohesiva.

---

## 💻 Compatibilidad y Requisitos del Sistema

Para garantizar una experiencia ultra fluida, rápida y sin interrupciones con las animaciones avanzadas de cristal esmerilado, ten en cuenta lo siguiente:

### 🐧 Distribuciones Compatibles
* **Compatibilidad Principal:** Arch Linux (Instalación base o archinstall).
* **Derivados de Arch:** EndeavourOS, ArcoLinux, CachyOS, Garuda Linux (Se recomienda una instalación mínima/limpia de estos derivados para evitar conflictos con entornos preexistentes).
* **NO Compatible:** Debian, Ubuntu, Fedora, Linux Mint, o cualquier distribución que no esté basada en pacman/Arch.

### ⚡ Recomendaciones de Hardware (Para máxima fluidez)
* **GPU:** 
  * **AMD Radeon:** ¡Muy recomendado! Funciona de manera nativa y perfecta con Wayland/Hyprland.
  * **Intel Graphics:** Totalmente compatible y fluido de forma nativa.
  * **Nvidia:** Compatible mediante controladores propietarios (el instalador detectará la GPU Nvidia y aplicará parches y variables de entorno automáticamente, aunque la experiencia puede variar respecto a AMD/Intel dependiendo del modelo).
* **Almacenamiento:** Unidad SSD o NVMe altamente recomendada para asegurar tiempos de carga instantáneos en scripts de terminal y caché de imágenes.
* **Memoria RAM:** Mínimo 4 GB, se recomiendan **8 GB o más** para manejar la multitarea con efectos de transparencia profunda (blur) sin cuellos de botella en la renderización.

---

## 🚀 Guía de Instalación Rápida

Para instalar **Pixi-Arch-A** en tu sistema Arch Linux de manera automática y sin complicaciones, sigue estos pasos:

### 1. Clonar el Repositorio
Usa el método HTTPS para descargar el proyecto de forma segura, rápida y sin necesidad de contraseñas ni llaves SSH:
```bash
git clone https://github.com/0o0-ct/Pixi-Arch-A.git ~/Pixi-Arch-A
```

### 2. Acceder al Directorio
Entra a la carpeta del proyecto descargado:
```bash
cd ~/Pixi-Arch-A
```

### 3. Dar Permisos de Ejecución al Script
Dale permisos de ejecución al script principal de instalación:
```bash
chmod +x install.sh
```

### 4. Ejecutar el Instalador
Inicia el instalador oficial interactivo en español y sigue las amigables instrucciones en pantalla:
```bash
./install.sh
```

### 🔄 Mantener el Sistema Actualizado
Si ya tienes instalado el sistema y deseas actualizarlo con las últimas mejoras, parches y personalizaciones de **Pixi-Arch-A**, ejecuta los siguientes comandos:
```bash
# 1. Acceder al directorio del proyecto
cd ~/Pixi-Arch-A

# 2. Traer los últimos cambios desde el repositorio de GitHub
git pull origin main

# 3. Volver a ejecutar el instalador para aplicar las actualizaciones
./install.sh
```

> [!TIP]
> El instalador es inteligente y detectará si ya tienes paquetes instalados. Solo actualizará y aplicará los nuevos perfiles y configuraciones estéticas de Pixi-Arch-A de forma completamente segura.

---

## 🛠️ Atajos de Teclado Clave y Uso

* **Bloqueo del Sistema instantáneo:** Presiona **`SUPER + L`** para bloquear tu pantalla con un efecto de desenfoque e información en tiempo real a través de `hyprlock` y `hypridle`.
* **Lanzador de Aplicaciones Rofi:** Presiona **`SUPER + D`** para abrir un menú flotante de cristal esmerilado que se adapta de forma inteligente a la paleta de colores de tu fondo.
* **Abrir Terminal Kitty:** Presiona **`SUPER + Enter`** para desplegar terminales traslúcidas que se superponen estéticamente como hojas de vidrio.
* **Alternar Paleta del Logo de Terminal:** Ejecuta el alternador rápido para cambiar la coloración del logotipo:
  ```bash
  ~/.config/fastfetch/toggle-color-gradient.py
  ```

---

## ⚙️ Gestión de Bloqueo e Inactividad (Timeout)
Toda la inactividad de tu pantalla se gestiona de forma centralizada en `hypridle.conf`:
* **Aviso de inactividad:** A los **9 minutos** (`timeout = 540`) recibirás una notificación de aviso en el sistema.
* **Bloqueo de seguridad:** A los **10 minutos** (`timeout = 600`) el sistema bloqueará la sesión automáticamente mediante el comando `loginctl lock-session`, el cual ejecuta el protector de pantalla seguro `hyprlock`.

---

<div align="center">

## 🤝 Créditos y Agradecimiento Original

> [!NOTE]
> **Reconocimiento:** Este proyecto es un fork y personalización profunda basada en el excelente instalador y dotfiles de **JaKooLit** ([Arch-Hyprland](https://github.com/JaKooLit/Arch-Hyprland)). Agradecemos enormemente la gran base, la arquitectura del script y la inspiración original que nos ha permitido construir este entorno de escritorio único y adaptado.

</div>
