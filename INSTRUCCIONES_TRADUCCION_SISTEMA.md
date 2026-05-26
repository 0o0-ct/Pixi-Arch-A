# 󰗊 Guía Paso a Paso para Traducir el Sistema a Español
## 💫 Destinado a Agentes de IA y Desarrolladores de Pixi-Arch-A 💫

Esta guía técnica explica paso a paso cómo traducir completamente al español todos los scripts de instalación, desinstalación, configuraciones y notificaciones de **`Pixi-Arch-A`**, garantizando que el código siga funcionando a la perfección (100% libre de errores de sintaxis en bash) y se mantenga la estética premium.

---

## 📌 Regla de Oro de la Traducción Técnica

> [!WARNING]
> **LO QUE SE TRADUCE:** 
> 1. Los textos que lee el usuario final (mensajes de logs, diálogos interactivos, preguntas, títulos de ventanas y notificaciones).
> 2. **Los comentarios explicativos dentro del código** (líneas que empiezan con `#` o `//`), para que todo el sistema esté documentado 100% en español.
>
> **LO QUE NO SE TRADUCE (BAJO NINGÚN CONCEPTO):**
> * Comandos de Linux (`sudo`, `pacman`, `git`, `systemctl`, `sed`, `grep`, `mkdir`, etc.).
> * Nombres de variables (ej. `$LOG`, `$package`, `$term`, `$scriptsDir`).
> * Parámetros o flags de comandos (ej. `--noconfirm`, `-S`, `-y`, `--yesno`).
> * Funciones de bash (ej. `execute_script()`, `install_package()`).
> * Nombres de paquetes o dependencias (ej. `pipewire`, `waybar`, `kitty`).

---

## 🛠️ Paso 1: Identificar los Archivos a Traducir

Para lograr una traducción total, el Agente debe abrir y revisar los archivos en los siguientes directorios:

1. **Scripts del Instalador:** Ubicados en `install-scripts/` (ej. `00-base.sh`, `01-hypr-pkgs.sh`, `02-Final-Check.sh`, `nvidia.sh`, `sddm.sh`, `zsh.sh`, etc.).
2. **Scripts de la Configuración Base:** Ubicados en `Hyprland-Dots/scripts/` (ej. `lib_copy.sh`, `lib_backup.sh`, `lib_prompts.sh`, `lib_update.sh`).
3. **Scripts de Usuario (Waybar, Notificaciones y Clima):** Ubicados en `Hyprland-Dots/config/hypr/UserScripts/` y `Hyprland-Dots/config/hypr/scripts/`.

---

## 📝 Paso 2: Fórmula para Traducir Salidas en Consola (`echo` y `printf`)

Al traducir mensajes impresos en la terminal, se deben conservar intactas las variables de color (`$OK`, `$ERROR`, `$YELLOW`, `$RESET`) y las variables de datos.

### ❌ Ejemplo Original (Inglés):
```bash
echo -e "${ERROR} - ${YELLOW}$pkg${RESET} installation failed. Please check $LOG."
```

###  Ejemplo Traducido al Español:
```bash
echo -e "${ERROR} - Error al instalar ${YELLOW}$pkg${RESET}. Por favor, revisa el archivo de registro $LOG."
```

*Observa cómo se tradujo "installation failed" por "Error al instalar" y "Please check" por "Por favor, revisa el archivo de registro", pero las variables `$pkg`, `$LOG`, `$ERROR`, `$YELLOW` y `$RESET` permanecieron exactamente iguales.*

---

## 🖥️ Paso 3: Fórmula para Traducir Diálogos de Consola (`whiptail`)

Los diálogos gráficos de Whiptail usan títulos, textos descriptivos y botones de selección. Solo se debe traducir el texto entre comillas. **Las dimensiones finales (números al final) nunca se tocan.**

### ❌ Ejemplo Original (Inglés):
```bash
if whiptail --title "Bluetooth Configuration" --yesno "Do you want to configure Bluetooth now?" 8 50; then
    echo "Configuring bluetooth..."
fi
```

###  Ejemplo Traducido al Español:
```bash
if whiptail --title "Configuración de Bluetooth" --yesno "¿Deseas configurar el Bluetooth en este momento?" 8 50; then
    echo "Configurando bluetooth..."
fi
```

*Para botones de Whiptail personalizados, también se pueden traducir los parámetros `--yes-button` y `--no-button`:*
* `--yes-button "Yes"` ➔ `--yes-button "Sí"`
* `--no-button "No"` ➔ `--no-button "No"`
* `--yes-button "Continue"` ➔ `--yes-button "Continuar"`
* `--no-button "Return"` ➔ `--no-button "Regresar"`

---

## 🔄 Paso 4: Fórmula para Traducir Entradas del Teclado (`read`)

Muchos scripts preguntan al usuario mediante un prompt `read`. Debes traducir la pregunta y asegurarte de que el script evalúe las respuestas en español (`s` / `si` / `sí`) además de las de inglés (`y` / `yes`).

### ❌ Ejemplo Original (Inglés):
```bash
echo -n "¿Te gustaría instalar software adicional? (s/n): "
read CHOICE
if [[ "$CHOICE" == "y" || "$CHOICE" == "yes" ]]; then
    # código
fi
```

###  Ejemplo Traducido al Español:
```bash
echo -n "¿Te gustaría instalar software adicional? (s/n): "
read CHOICE
CHOICE=$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]') # convierte a minúsculas
if [[ "$CHOICE" == "s" || "$CHOICE" == "si" || "$CHOICE" == "sí" || "$CHOICE" == "y" || "$CHOICE" == "yes" ]]; then
    # código
fi
```

---

## 🏷️ Paso 5: Un-branding en las Traducciones (Reemplazo de Firmas)

Durante la traducción, aprovecha para purgar firmas antiguas o caracteres que no pertenezcan al sistema **`Pixi-Arch-A`**:
* Reemplaza `"KooL's Hyprland"` o `"JaKooLit's Dots"` por `"Pixi-Arch-A"`.
* Reemplaza `"KooL's Dots"` por `"dotfiles de Pixi-Arch-A"`.
* Remueve la bandera `"🇵🇭"` de los textos de salida e introduce con orgullo la bandera de **Guatemala (`"🇬🇹"`)** en su lugar como la bandera oficial de **Pixi-Arch-A**.

---

## 🚀 Ejercicio Práctico de Traducción para el Agente de IA

Cuando el creador te diga: **"Agente, traduce el archivo `install-scripts/bluetooth.sh`"**, debes seguir esta fórmula estructurada:

### 1. Examinar el código original:
```bash
#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Bluetooth configure

if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

echo -e "${NOTE} Installing Bluetooth packages..."
install_package bluez
install_package bluez-utils

echo -e "${NOTE} Enabling Bluetooth Service..."
sudo systemctl enable --now bluetooth.service
```

### 2. Escribir y guardar la versión traducida:
```bash
#!/bin/bash
# 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 #
# Configuración de Bluetooth

if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Error al cargar Global_functions.sh"
  exit 1
fi

echo -e "${NOTE} Instalando los paquetes de Bluetooth..."
install_package bluez
install_package bluez-utils

echo -e "${NOTE} Habilitando el Servicio de Bluetooth..."
sudo systemctl enable --now bluetooth.service
```

---

## 💾 Sincronización en GitHub despúes de traducir

Una vez que hayas traducido un lote de archivos, ejecuta la secuencia de comandos de Git para mantener el repositorio público al día:

```bash
git add .
git commit -m "translate: traducción al español de scripts de instalación"
git push origin main
git push origin main:master
```

¡Siguiendo esta guía, la traducción del sistema será sumamente uniforme, rápida, elegante y profesional!
