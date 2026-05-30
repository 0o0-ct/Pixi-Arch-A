#!/bin/bash
# https://github.com/0o0-ct/Pixi-Arch-A

clear

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Crear directorio para los registros de instalación
if [ ! -d Install-Logs ]; then
    mkdir Install-Logs
fi

# Nombrar el archivo de registro con la fecha y hora actuales
LOG="Install-Logs/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"

# Comprobar si se ejecuta como root. Si es así, el script saldrá
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR}  ¡¡Este script ${WARNING}NO${RESET} debe ejecutarse como root!! Saliendo......." | tee -a "$LOG"
    printf "\n%.0s" {1..2} 
    exit 1
fi

# Comprobar si el paquete PulseAudio está instalado
if pacman -Qq | grep -qw '^pulseaudio$'; then
    echo "$ERROR Se ha detectado PulseAudio instalado. Desinstálalo primero o edita install.sh en la línea 211 (execute_script 'pipewire.sh')." | tee -a "$LOG"
    printf "\n%.0s" {1..2} 
    exit 1
fi

# Comprobar si base-devel está instalado
if pacman -Q base-devel &> /dev/null; then
    echo "base-devel ya está instalado."
else
    echo "$NOTE Instalando base-devel.........."

    if sudo pacman -S --noconfirm base-devel; then
        echo "👌 ${OK} base-devel se ha instalado correctamente." | tee -a "$LOG"
    else
        echo "❌ $ERROR base-devel no se encontró ni se puede instalar."  | tee -a "$LOG"
        echo "$ACTION Por favor, instala base-devel manualmente antes de ejecutar este script... Saliendo" | tee -a "$LOG"
        exit 1
    fi
fi

# Instalar whiptail si no está instalado. Necesario para esta versión
if ! command -v whiptail >/dev/null; then
    echo "${NOTE} - whiptail no está instalado. Instalando..." | tee -a "$LOG"
    sudo pacman -S --noconfirm libnewt
    printf "\n%.0s" {1..1}
fi

clear

printf "\n%.0s" {1..2}  
echo -e "${MAGENTA}
    ██████╗ ██╗██╗  ██╗██╗      █████╗ ██████╗  ██████╗██╗  ██╗      █████╗ 
    ██╔══██╗██║╚██╗██╔╝██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║     ██╔══██╗
    ██████╔╝██║ ╚███╔╝ ██║     ███████║██████╔╝██║     ███████║     ███████║
    ██╔═══╝ ██║ ██╔██╗ ██║     ██╔══██║██╔══██╗██║     ██╔══██║     ██╔══██║
    ██║     ██║██╔╝ ██╗██║     ██║  ██║██║  ██║╚██████╗██║  ██║     ██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝     ╚═╝  ╚═╝
${RESET}"
printf "\n%.0s" {1..1} 

# Welcome message using whiptail (for displaying information)
whiptail --title "Instalador de Pixi-Arch-A (2026)" \
    --msgbox "¡Bienvenido al instalador oficial de Pixi-Arch-A (2026)!!!\n\n\
ATENCIÓN: ¡Es muy recomendable ejecutar una actualización completa del sistema y reiniciar primero!\n\n\
NOTA: Si estás instalando en una máquina virtual (VM), ¡asegúrate de habilitar la aceleración 3D en tu configuración o de lo contrario Hyprland podría no iniciar!" \
    15 80

# Preguntar si el usuario desea continuar
if ! whiptail --title "¿Proceder con la instalación?" \
    --yesno "¿Deseas continuar con la instalación de Pixi-Arch-A?" 7 55; then
    echo -e "\n"
    echo "❌ ${INFO} Elegiste ${YELLOW}NO${RESET} continuar. ${YELLOW}Saliendo...${RESET}" | tee -a "$LOG"
    echo -e "\n" 
    exit 1
fi

echo "👌 ${OK} ${MAGENTA}¡Excelente!..${RESET} ${SKY_BLUE}comencemos con la instalación...${RESET}" | tee -a "$LOG"

sleep 1
printf "\n%.0s" {1..1}

# Instalar pciutils si no está instalado. Necesario para detectar la GPU
if ! pacman -Qs pciutils > /dev/null; then
    echo "${NOTE} - pciutils no está instalado. Instalando..." | tee -a "$LOG"
    sudo pacman -S --noconfirm pciutils
    printf "\n%.0s" {1..1}
fi

# Ruta al directorio de scripts de instalación
script_directory=install-scripts

# Función para ejecutar un script si existe y hacerlo ejecutable
execute_script() {
    local script="$1"
    local script_path="$script_directory/$script"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if [ -x "$script_path" ]; then
            env "$script_path"
        else
            echo "Error al dar permisos de ejecución al script '$script'."
        fi
    else
        echo "No se encontró el script '$script' en '$script_directory'."
    fi
}


## Valores por defecto para las opciones (serán sobreescritos por el preset si existe)
gtk_themes="OFF"
bluetooth="OFF"
nautilus="OFF"
quickshell="OFF"
sddm="OFF"
sddm_theme="OFF"
xdph="OFF"
zsh="OFF"
rog="OFF"
dots="OFF"
input_group="OFF"
nvidia="OFF"
nouveau="OFF"

# Función para cargar el archivo preset
load_preset() {
    if [ -f "$1" ]; then
        echo "✅ Cargando preset: $1"
        source "$1"
    else
        echo "⚠️ No se encontró el archivo preset: $1. Usando valores predeterminados."
    fi
}

# Comprobar si se pasó el argumento --preset
if [[ "$1" == "--preset" && -n "$2" ]]; then
    load_preset "$2"
fi

# Comprobar si yay o paru está instalado
echo "${INFO} - Verificando si yay o paru están instalados"
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo "${CAT} - No se encontró ni yay ni paru. Pidiendo al USUARIO 🗣️ que seleccione..."
    while true; do
        aur_helper=$(whiptail --title "Ni Yay ni Paru están instalados" --checklist "Ni Yay ni Paru están instalados. Choose one AUR.\n\nNOTE: Select only 1 AUR helper!\nINFO: spacebar to select" 12 60 2 \
            "yay" "Ayudante AUR yay" "OFF" \
            "paru" "Ayudante AUR paru" "OFF" \
            3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then  
            echo "❌ ${INFO} Cancelaste la selección. ${YELLOW}¡Adiós!${RESET}" | tee -a "$LOG"
            exit 0 
        fi

        if [ -z "$aur_helper" ]; then
            whiptail --title "Error" --msgbox "Debes seleccionar al menos un AUR helper para continuar." 10 60 2
            continue 
        fi

        echo "${INFO} - Seleccionaste: $aur_helper como tu AUR helper"  | tee -a "$LOG"

        aur_helper=$(echo "$aur_helper" | tr -d '"')

        # Comprobar si se seleccionaron múltiples ayudantes
        if [[ $(echo "$aur_helper" | wc -w) -ne 1 ]]; then
            whiptail --title "Error" --msgbox "Debes seleccionar exactamente un AUR helper." 10 60 2
            continue  
        else
            break 
        fi
    done
else
    echo "${NOTE} - El AUR helper ya está instalado. Omitiendo selección de AUR helper."
fi

# Lista de servicios para comprobar gestores de inicio de sesión
services=("gdm.service" "gdm3.service" "lightdm.service" "lxdm.service")

# Función para comprobar si hay servicios de inicio activos
check_services_running() {
    active_services=()  # Array to store active services
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            active_services+=("$svc")  
        fi
    done

    if [ ${#active_services[@]} -gt 0 ]; then
        return 0  
    else
        return 1  
    fi
}

if check_services_running; then
    active_list=$(printf "%s\n" "${active_services[@]}")

    # Mostrar los gestores de inicio activos en whiptail
    whiptail --title "Se detectaron gestores de inicio de sesión activos distintos a SDDM" \
        --msgbox "Los siguientes gestores de inicio están activos:\n\n$active_list\n\nSi deseas instalar SDDM y el tema de SDDM, detén y deshabilita los servicios de arriba y reinicia antes de ejecutar este script.\n\nTu opción de instalar SDDM ha sido removida\n\n- Pixi-Arch-A " 23 80
fi

# Comprobar si se detecta una GPU NVIDIA
nvidia_detected=false
if lspci | grep -i "nvidia" &> /dev/null; then
    nvidia_detected=true
    whiptail --title "GPU NVIDIA Detectada" --msgbox "GPU NVIDIA detectada en tu sistema.\n\nNOTA: El script instalará nvidia-dkms, nvidia-utils y nvidia-settings si decides configurarla." 12 60
fi

# Inicializar el arreglo de opciones para whiptail
options_command=(
    whiptail --title "Seleccionar Opciones" --checklist "Elige qué instalar o configurar\nNOTA: 'ESPACIO' para seleccionar y 'TAB' para cambiar selección" 28 85 20
)

# Añadir opciones de NVIDIA si se detecta
if [ "$nvidia_detected" == "true" ]; then
    options_command+=(
        "nvidia" "¿Quieres que el script configure la GPU NVIDIA?" "OFF"
        "nouveau" "¿Quieres poner en lista negra a Nouveau?" "OFF"
    )
fi

# Añadir opción 'input_group' si el usuario no está
input_group_detected=false
if ! groups "$(whoami)" | grep -q '\binput\b'; then
    input_group_detected=true
    whiptail --title "Grupo Input" --msgbox "Actualmente no estás en el grupo input.\n\nAñadirte al grupo input puede ser necesario para el estado del teclado en Waybar." 12 60
fi

# Añadir opción 'input_group' si es necesario
if [ "$input_group_detected" == "true" ]; then
    options_command+=(
        "input_group" "¿Añadir tu USUARIO al grupo input para funciones de Waybar?" "OFF"
    )
fi

# Añadir SDDM si no se encontró gestor activo
if ! check_services_running; then
    options_command+=(
        "sddm" "¿Instalar y configurar el gestor de inicio de sesión SDDM?" "OFF"
        "sddm_theme" "¿Descargar e instalar un tema adicional para SDDM?" "OFF"
    )
fi

# Añadir el resto de las opciones estáticas
options_command+=(
    "gtk_themes" "¿Instalar temas GTK? (necesario para Dark/Light)" "OFF"
    "bluetooth" "¿Quieres que el script configure el Bluetooth?" "OFF"
    "nautilus" "¿Deseas instalar el gestor de archivos GNOME Files (Nautilus)?" "OFF"
    "quickshell" "¿Instalar quickshell para la Vista de Escritorio?" "OFF"
    "xdph" "¿Instalar XDG-DESKTOP-PORTAL-HYPRLAND (para compartir pantalla)?" "OFF"
    "zsh" "¿Instalar la shell zsh con personalización Pixi-Arch-A?" "OFF"
    "rog" "¿Estás instalando en una laptop Asus ROG?" "OFF"
    "dots" "Descargar e instalar configuraciones y dotfiles de Pixi-Arch-A" "OFF"
)

# Capturar las opciones seleccionadas
while true; do
    selected_options=$("${options_command[@]}" 3>&1 1>&2 2>&3)

    # Comprobar si se presionó Cancelar
    if [ $? -ne 0 ]; then
        echo -e "\n"
        echo "❌ ${INFO} 🫵 Cancelaste la selección. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
        exit 0  # Exit the script if Cancel is pressed
    fi

    # Si no se seleccionó nada, notificar y reiniciar
    if [ -z "$selected_options" ]; then
        whiptail --title "Advertencia" --msgbox "No se seleccionó ninguna opción. Selecciona al menos una." 10 60
        continue  # Return to selection if no options selected
    fi

    # Limpiar comillas y espacios de la entrada
    selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')

    # Convertir las opciones a arreglo
    IFS=' ' read -r -a options <<< "$selected_options"

    # Comprobar si la opción 'dots' fue seleccionada
    dots_selected="OFF"
    for option in "${options[@]}"; do
        if [[ "$option" == "dots" ]]; then
            dots_selected="ON"
            break
        fi
    done

    # Si 'dots' no se selecciona, mostrar advertencia
    if [[ "$dots_selected" == "OFF" ]]; then
        # Show a note about not selecting the "dots" option
        if ! whiptail --title "Configuraciones de Pixi-Arch-A" --yesno \
        "No has seleccionado instalar las configuraciones y dotfiles personalizadas de Pixi-Arch-A.\n\nNOTA: Si continúas sin las Dots, Hyprland iniciará con una configuración vacía por defecto y no podrás disfrutar del diseño de cristal esmerilado premium.\n\n¿Deseas continuar la instalación sin las dotfiles de Pixi-Arch-A?" \
        --yes-button "Continuar" --no-button "Regresar" 15 90; then
            echo "🔙 Regresando a las opciones..." | tee -a "$LOG"
            continue
        else
            # User chose to continue
            echo "${INFO} ⚠️ Continuando SIN la instalación de las dotfiles..." | tee -a "$LOG"
			printf "\n%.0s" {1..1}
        fi
    fi

    # Preparar el mensaje de confirmación
    confirm_message="Has seleccionado las siguientes opciones:\n\n"
    for option in "${options[@]}"; do
        confirm_message+=" - $option\n"
    done
    confirm_message+="\n¿Estás de acuerdo con estas opciones?"

    # Diálogo de confirmación
    if ! whiptail --title "Confirmar Opciones" --yesno "$(printf "%s" "$confirm_message")" 25 80; then
        echo -e "\n"
        echo "❌ ${SKY_BLUE}No estás de acuerdo${RESET}. ${YELLOW}Regresando a las opciones...${RESET}" | tee -a "$LOG"
        continue 
    fi

    echo "👌 ${OK} Confirmaste tus opciones. Procediendo con la instalación de ${SKY_BLUE}Pixi-Arch-A 🇬🇹...${RESET}" | tee -a "$LOG"
    break  
done

printf "\n%.0s" {1..1}

# Asegurando que base-devel esté instalado
execute_script "00-base.sh"
sleep 1
execute_script "pacman.sh"
sleep 1

# Ejecutar AUR helper
if [ "$aur_helper" == "paru" ]; then
    execute_script "paru.sh"
elif [ "$aur_helper" == "yay" ]; then
    execute_script "yay.sh"
fi

sleep 1

# Ejecutar los scripts relacionados con Hyprland
echo "${INFO} Instalando los paquetes adicionales de ${SKY_BLUE}Pixi-Arch-A...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "01-hypr-pkgs.sh"

echo "${INFO} Instalando ${SKY_BLUE}pipewire y pipewire-audio...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "pipewire.sh"

echo "${INFO} Instalando ${SKY_BLUE}fuentes necesarias...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "fonts.sh"

echo "${INFO} Instalando ${SKY_BLUE}Hyprland...${RESET}"
sleep 1
execute_script "hyprland.sh"

# Limpiar opciones seleccionadas
selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')

# Convertir opciones en arreglo
IFS=' ' read -r -a options <<< "$selected_options"

# Iterar por las opciones seleccionadas
for option in "${options[@]}"; do
    case "$option" in
        sddm)
            if check_services_running; then
                active_list=$(printf "%s\n" "${active_services[@]}")
                whiptail --title "Error" --msgbox "Uno de los siguientes servicios de inicio está activo:\n$active_list\n\nPor favor deténlo o NO elijas SDDM." 12 60
                exec "$0"  
            else
                echo "${INFO} Instalando y configurando ${SKY_BLUE}SDDM...${RESET}" | tee -a "$LOG"
                execute_script "sddm.sh"
            fi
            ;;
        nvidia)
            echo "${INFO} Configurando ${SKY_BLUE}cosas de nvidia${RESET}" | tee -a "$LOG"
            execute_script "nvidia.sh"
            ;;
        nouveau)
            echo "${INFO} poniendo ${SKY_BLUE}nouveau${RESET} en lista negra"
            execute_script "nvidia_nouveau.sh" | tee -a "$LOG"
            ;;
        gtk_themes)
            echo "${INFO} Instalando ${SKY_BLUE}temas GTK...${RESET}" | tee -a "$LOG"
            execute_script "gtk_themes.sh"
            ;;
        input_group)
            echo "${INFO} Añadiendo el usuario al ${SKY_BLUE}grupo input...${RESET}" | tee -a "$LOG"
            execute_script "InputGroup.sh"
            ;;
        quickshell)
            echo "${INFO} Instalando ${SKY_BLUE}quickshell para la Vista de Escritorio...${RESET}" | tee -a "$LOG"
            execute_script "quickshell.sh"
            ;;
        xdph)
            echo "${INFO} Instalando ${SKY_BLUE}xdg-desktop-portal-hyprland...${RESET}" | tee -a "$LOG"
            execute_script "xdph.sh"
            ;;
        bluetooth)
            echo "${INFO} Configurando ${SKY_BLUE}Bluetooth...${RESET}" | tee -a "$LOG"
            execute_script "bluetooth.sh"
            ;;
        nautilus)
            echo "${INFO} Instalando ${SKY_BLUE}el gestor de archivos GNOME Files (Nautilus)...${RESET}" | tee -a "$LOG"
            execute_script "nautilus.sh"
            execute_script "nautilus_default.sh"
            ;;
        sddm_theme)
            echo "${INFO} Descargando e instalando ${SKY_BLUE}un tema adicional para SDDM...${RESET}" | tee -a "$LOG"
            execute_script "sddm_theme.sh"
            ;;
        zsh)
            echo "${INFO} Instalando ${SKY_BLUE}zsh con la personalización Pixi-Arch-A...${RESET}" | tee -a "$LOG"
            execute_script "zsh.sh"
            ;;
        rog)
            echo "${INFO} Instalando ${SKY_BLUE}paquetes para laptop ROG...${RESET}" | tee -a "$LOG"
            execute_script "rog.sh"
            ;;
        dots)
            echo "${INFO} Instalando las configuraciones y dotfiles de ${SKY_BLUE}Pixi-Arch-A...${RESET}" | tee -a "$LOG"
            execute_script "dotfiles-main.sh"
            ;;
        *)
            echo "Opción desconocida: $option" | tee -a "$LOG"
            ;;
    esac
done

sleep 1
# copiar fastfetch config si arch.png no existe
if [ ! -f "$HOME/.config/fastfetch/arch.png" ]; then
    cp -r assets/fastfetch "$HOME/.config/"
fi

clear

# comprobación final de los paquetes esenciales
execute_script "02-Final-Check.sh"

printf "\n%.0s" {1..1}

# Comprobar si hyprland está instalado
if pacman -Q hyprland &> /dev/null || pacman -Q hyprland-git &> /dev/null; then
    printf "\n ${OK} 👌 Hyprland está instalado. Sin embargo, puede que falten paquetes esenciales. ¡Revisa arriba!"
    printf "\n${CAT} Ignora este mensaje si dice que ${YELLOW}Todos los paquetes esenciales${RESET} están instalados arriba\n"
    sleep 2
    printf "\n%.0s" {1..2}

    printf "${SKY_BLUE}¡Muchas gracias${RESET} 🫰 por usar ${MAGENTA}Pixi-Arch-A 🇬🇹${RESET}! ${YELLOW}¡Disfruta tu nuevo sistema y ten un gran día!${RESET}"
    printf "\n%.0s" {1..2}

    printf "\n${NOTE} Puedes iniciar Hyprland escribiendo ${SKY_BLUE}Hyprland${RESET} (si no instalaste SDDM) (¡nota la H mayúscula!).\n"
    printf "\n${NOTE} Sin embargo, se ${YELLOW}recomienda encarecidamente reiniciar${RESET} el sistema.\n\n"

    while true; do
        echo -n "${CAT} ¿Deseas reiniciar el sistema ahora? (s/n): "
        read HYP
        HYP=$(echo "$HYP" | tr '[:upper:]' '[:lower:]')

        if [[ "$HYP" == "s" || "$HYP" == "si" || "$HYP" == "sí" || "$HYP" == "y" || "$HYP" == "yes" ]]; then
            echo "${INFO} Reiniciando el sistema ahora..."
            systemctl reboot 
            break
        elif [[ "$HYP" == "n" || "$HYP" == "no" ]]; then
            echo "👌 ${OK} Elegiste NO reiniciar"
            printf "\n%.0s" {1..1}
            # Check if NVIDIA GPU is present
            if lspci | grep -i "nvidia" &> /dev/null; then
                echo "${INFO} SIN EMBARGO, se detectó una ${YELLOW}GPU NVIDIA${RESET}. Te recordamos que es necesario REINICIAR el SISTEMA..."
                printf "\n%.0s" {1..1}
            fi
            break
        else
            echo "${WARN} Respuesta inválida. Por favor, responde con 's' o 'n'."
        fi
    done
else
    # Mostrar error si no está instalado
    printf "\n${WARN} Hyprland NO está instalado. Por favor, revisa el archivo de registro en Install-Logs/..."
    printf "\n%.0s" {1..3}
    exit 1
fi


printf "\n%.0s" {1..2}