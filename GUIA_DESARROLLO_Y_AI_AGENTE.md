# 󰣇 Guía de Desarrollo, Traducción y Estructura para Agentes de IA
## 💫 Proyecto: Pixi-Arch-A 💫

Este documento contiene las directrices técnicas y de diseño fundamentales para cualquier Agente de Inteligencia Artificial (por ejemplo: Antigravity, Gemini 3.5 Flash, Gemini 3.1 Pro) que colabore con el creador **`0o0-ct`** en el desarrollo y mantenimiento del sistema operativo **`Pixi-Arch-A`**.

> [!IMPORTANT]
> **REGLA DE ORO PARA EL AGENTE:** Toda la interfaz de usuario, los scripts de instalación, desinstalación y configuración deben permanecer en **Español de alta calidad (Castellano)**. Ningún script debe mostrar menciones externas a marcas antiguas como "JaKooLit" o banderas ajenas al proyecto como "🇵🇭" en los diálogos interactivos, manteniendo la identidad exclusiva de **`Pixi-Arch-A`**.

---

## 1. 🏷️ Identidad de Marca y Desvinculación (Un-branding)

* **Nombre Oficial:** El sistema se llama exclusivamente **`Pixi-Arch-A`**. La letra **`-A`** al final es obligatoria y rinde tributo a la colaboración con el agente de IA **Antigravity**.
* **Branding Limpio:** Todos los comentarios de cabecera en los archivos `.sh` y `.conf` deben contener el enlace oficial del repositorio: `# https://github.com/0o0-ct/Pixi-Arch-A`.
* **Respeto a los Orígenes:** Para cumplir con la ética de software libre, los bloques de créditos de agradecimiento ubicados al final de los archivos `README.md` deben mantenerse intactos, reconociendo el trabajo original de JaKooLit (Arch-Hyprland), pero la marca interactiva visible al usuario final debe ser 100% **`Pixi-Arch-A`**.

---

## 2. 🗣️ Estándar de Traducción al Español

* **Textos del Instalador (`install.sh`) y Desinstalador (`uninstall.sh`):** Todos los diálogos interactivos de Whiptail (mensajes, confirmaciones, advertencias) y los logs de progreso impresos en consola deben estar escritos en un español elegante y comprensible.
* **Preservación de Código:** **NO** se deben traducir palabras clave de programación, nombres de variables, llamadas a funciones, utilidades de terminal o rutas lógicas del sistema (por ejemplo, `dots`, `exec-once`, `check_services_running`, etc.). La traducción se limita exclusivamente al texto que lee el usuario final.
* **Soporte de Entrada Localizado:** Las preguntas interactivas de respuesta binaria en consola deben admitir respuestas localizadas en español (`s` / `si` / `sí` / `y` / `yes`) de forma no restrictiva.

---

## 3. 🔮 Estructura de Diseño "Frosted Glassmorphism" (Cristal Esmerilado)

El sistema debe mantener por defecto la configuración premium de cristal esmerilado que hemos diseñado:

### A.Compositor Hyprland (`UserDecorations.conf` y `WindowRules.conf`)
* **Desenfoque Profundo y Granulado:**
  * `size = 10` y `passes = 4` para una difuminación tridimensional ultra-suave.
  * `noise = 0.03` para dotar de una textura orgánica de vidrio esmerilado real.
  * `contrast = 1.15`, `brightness = 0.82` y `vibrancy = 0.3` para una legibilidad y contraste perfectos.
* **Translucidez en Capas Altas (Layer Rules):**
  * Se debe habilitar `layerrule = blur, <componente>` e `ignore_alpha 0.1` en `WindowRules.conf` para **Waybar**, **Rofi**, **SwayNC**, **Wlogout** y las notificaciones del sistema. Esto evita que los overlays de baja opacidad se rendericen en negro sólido.
* **Transparencia de Ventanas:**
  * Opacidad de ventanas de Hyprland configurada en `active_opacity = 0.86` e `inactive_opacity = 0.78`.
  * **Thunar "Ultra-Glass":** El gestor de archivos Thunar debe mantener opacidad del `80%` (activo) y `70%` (inactivo), acompañado de un borde ultra-fino brillante semi-transparente (`rgba(ffffff66)` y `rgba(ffffff1a)`).

### B. Barra de Tareas Waybar
* **Tema por Defecto:** El script de despliegue `copy.sh` debe inicializar el sistema con el archivo de estilos **`[Colored] Translucent.css`** por defecto.
* **Tarjeta de Cristal Flotante:** La barra de Waybar debe mantener un fondo translúcido (`rgba(15, 20, 30, 0.34)`), bordes finos blancos semi-transparentes y sombras de tarjeta flotante.

### C. Lanzador Rofi
* **Fondo de Wallust RGBA:** La plantilla de Wallust para Rofi (`colors-rofi.rasi`) debe aplicar opacidades RGBA sobre la paleta generada: `background: rgba({{background | rgb}}, 0.35)`.
* **Estilo de Cristal:** El archivo de tema `KooL_style-4.rasi` debe usar bordes blancos finos semi-transparentes (`rgba(255, 255, 255, 0.15)`) y bordes redondeados amplios.

---

## 4. ⚡ Optimización de Rendimiento e Instantaneidad

* **Bloqueo Rápido de Pantalla (`SUPER + L`):**
  * El atajo de teclado para bloquear la pantalla debe estar mapeado a la combinación natural **`SUPER + L`** en `Keybinds.conf`.
  * **Bloqueo Asíncrono:** El script de bloqueo `LockScreen.sh` debe llamar a la actualización de red del clima `WeatherWrap.sh` en segundo plano utilizando el operador **`&`** (`bash .../WeatherWrap.sh >/dev/null 2>&1 &`). Esto evita retrasos y bloqueos, permitiendo que la PC se bloquee instantáneamente (en menos de 0.5 segundos).

---

## 5. 📥 Repositorio Ligero y Optimización de Git

* **Sin Archivos Pesados en el Historial:** El historial de Git del repositorio debe permanecer completamente limpio y optimizado. El archivo `.gitignore` en la raíz debe excluir estrictamente la carpeta física de wallpapers pesados:
  ```gitignore
  Hyprland-Dots/wallpapers/*
  !Hyprland-Dots/wallpapers/download_wallpapers.sh
  ```
* **Descarga Dinámica de Wallpapers:** En su lugar, el script `download_wallpapers.sh` se encargará de descargar las imágenes 4K directamente desde el servidor durante el proceso de instalación guiada.

---

## 🚀 6. Sincronización y Despliegue en GitHub

Cualquier cambio, personalización o corrección que se realice en el sistema de desarrollo local debe ser sincronizado de manera inmediata con el repositorio remoto mediante el protocolo seguro HTTPS ya configurado:

```bash
# 1. Asegurar que nos encontramos en el directorio raíz del proyecto
cd ~/JaKooLit

# 2. Agregar todos los cambios realizados
git add .

# 3. Crear un commit semántico y limpio descriptivo
git commit -m "feat/fix: descripción técnica de mis mejoras en español"

# 4. Empujar los cambios simultáneamente a ambas ramas del repositorio remoto
git push origin main
git push origin main:master
```

Esta estructura garantiza que la base de datos de código permanezca en perfecta consonancia y que las compilaciones futuras de **`Pixi-Arch-A`** conserven su alto nivel de excelencia estética, fluidez extrema y portabilidad.
