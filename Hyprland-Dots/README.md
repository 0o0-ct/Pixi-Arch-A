# 󰣇  Pixi-Arch-A (Configuraciones y Dotfiles)

<div align="center">

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-85A5FF?style=for-the-badge&logo=hyprland&logoColor=white)
![Theme](https://img.shields.io/badge/Aesthetics-Frosted%20Glass-FF4136?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-v1.0.0--Antigravity-white?style=for-the-badge)

</div>

---

> [!IMPORTANT]
> Esta carpeta contiene los **Dotfiles (archivos de configuración)** nativos y personalizados para tu sistema de escritorio **Pixi-Arch-A**. Estas configuraciones son empaquetadas y aplicadas automáticamente en tu equipo mediante el script de despliegue.

---

## 🔮 Estructura de Configuraciones (Nuestras Modificaciones)

Esta suite de configuraciones ha sido modificada a fondo para ofrecer un entorno visual impecable y un rendimiento excepcional:

* **`config/hypr/UserConfigs/UserDecorations.conf`:** Define el motor de cristal esmerilado de Hyprland con desenfoque de 4 pasadas (`passes = 4`), granulado denso y transparencias del `86%` en ventanas activas.
* **`config/hypr/UserConfigs/WindowRules.conf`:** Establece las reglas de ventanas y capas, incluyendo la translucidez extrema para Thunar y su borde brillante de cristal.
* **`config/hypr/scripts/KooLsDotsUpdate.sh`:** Script del actualizador de sistema totalmente personalizado para apuntar e instalar desde tu repositorio personal de GitHub `0o0-ct/Pixi-Arch`.

---

## 🚀 Despliegue de Configuraciones

Para aplicar de forma segura estos archivos y configuraciones en tu sistema, se incluye un script automático de copia:

```bash
# Otorgar permisos de ejecución
chmod +x copy.sh

# Ejecutar el instalador de dotfiles
./copy.sh
```

El script `copy.sh` se encargará de realizar copias de seguridad de tus configuraciones antiguas e instalar los nuevos archivos esmerilados y personalizados de **Pixi-Arch-A** en tu directorio `~/.config/` al instante.

---

<div align="center">

## 🤝 Créditos y Agradecimiento Original

> [!NOTE]
> **Reconocimiento:** Esta base de configuraciones y dotfiles ha sido adaptada y evolucionada a partir del trabajo original de **JaKooLit** ([Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots)). Agradecemos enormemente su grandiosa base estructural para construir nuestra propia experiencia a medida en **Pixi-Arch-A**.

</div>
