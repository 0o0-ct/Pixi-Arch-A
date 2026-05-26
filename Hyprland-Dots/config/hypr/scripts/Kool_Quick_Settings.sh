#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# Rofi menu for KooL Hyprland Quick Settings (SUPER SHIFT E)
# Updated for UserConfigs/configs separation

# Modify this config file for default terminal and EDITOR
config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.conf"

tmp_config_file=$(mktemp)
sed 's/^\$//g; s/ = /=/g' "$config_file" > "$tmp_config_file"
source "$tmp_config_file"
# ##################################### #

# variables
configs="$HOME/.config/hypr/configs"
UserConfigs="$HOME/.config/hypr/UserConfigs"
rofi_theme="$HOME/.config/rofi/config-edit.rasi"
msg='⁉️  Elige que hacer  ⁉️'
iDIR="$HOME/.config/swaync/images"
scriptsDir="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

# Function to show info notification
show_info() {
    if [[ -f "$iDIR/info.png" ]]; then
        notify-send -i "$iDIR/info.png" "Info" "$1"
    else
        notify-send "Info" "$1"
    fi
}
# Function to toggle Rainbow Borders script availability and refresh UI components
toggle_rainbow_borders() {
    local rainbow_script="$UserScripts/RainbowBorders.sh"
    local deshabilitado_sh_bak="${rainbow_script}.bak"           # RainbowBorders.sh.bak
    local deshabilitado_bak_sh="$UserScripts/RainbowBorders.bak.sh" # RainbowBorders.bak.sh (created by copy.sh when deshabilitado)
    local refresh_script="$scriptsDir/Refresh.sh"
    local status=""

    # If both deshabilitado variants exist, keep the newer one to avoid ambiguity
    if [[ -f "$disabled_sh_bak" && -f "$disabled_bak_sh" ]]; then
        if [[ "$disabled_sh_bak" -nt "$disabled_bak_sh" ]]; then
            rm -f "$disabled_bak_sh"
        else
            rm -f "$disabled_sh_bak"
        fi
    fi

    if [[ -f "$rainbow_script" ]]; then
        # Currently habilitado -> disable to canonical .sh.bak
        if mv "$rainbow_script" "$disabled_sh_bak"; then
            status="disabled"
            if command -v hyprctl &>/dev/null; then
                hyprctl reload >/dev/null 2>&1 || true
            fi
        fi
    elif [[ -f "$disabled_sh_bak" ]]; then
        # Deshabilitado (.sh.bak) -> enable
        if mv "$disabled_sh_bak" "$rainbow_script"; then
            status="enabled"
        fi
    elif [[ -f "$disabled_bak_sh" ]]; then
        # Deshabilitado (.bak.sh) -> enable (normalize to .sh)
        if mv "$disabled_bak_sh" "$rainbow_script"; then
            status="enabled"
        fi
    else
        show_info "No se encontró el script RainbowBorders en $UserScripts."
        return
    fi

    # Run refresh if available, otherwise apply borders directly
    if [[ -x "$refresh_script" ]]; then
        "$refresh_script" >/dev/null 2>&1 &
    elif [[ "$current" != "disabled" && -x "$rainbow_script" ]]; then
        "$rainbow_script" >/dev/null 2>&1 &
    fi

    if [[ -n "$status" ]]; then
        show_info "Rainbow Borders ${status}."
    fi
}

# Submenu to choose Rainbow Borders mode (disable, wallust_random, rainbow, gradient_flow)
rainbow_borders_menu() {
    local rainbow_script="$UserScripts/RainbowBorders.sh"
    local deshabilitado_sh_bak="${rainbow_script}.bak"
    local deshabilitado_bak_sh="$UserScripts/RainbowBorders.bak.sh"
    local refresh_script="$scriptsDir/Refresh.sh"

    # Determine current mode/status (internal)
    local current="disabled"
    if [[ -f "$rainbow_script" ]]; then
        current=$(grep -E '^EFFECT_TYPE=' "$rainbow_script" 2>/dev/null | sed -E 's/^EFFECT_TYPE="?([^"]*)"?/\1/')
        [[ -z "$current" ]] && current="unknown"
    fi

    # Map internal mode to friendly display
    local current_display="$current"
    case "$current" in
        wallust_random) current_display="Color Wallust" ;;
        rainbow) current_display="Arcoíris Original" ;;
        gradient_flow) current_display="Flujo de Gradiente" ;;
        deshabilitado) current_display="Deshabilitado" ;;
    esac


    # Build options and prompt
    local options="Deshabilitar Bordes Arcoíris\nColor Wallust\nArcoíris Original\nFlujo de Gradiente"
    local choice
    choice=$(printf "%b" "$options" | rofi -i -dmenu -config "$rofi_theme" -mesg "Bordes Arcoíris: actual = $current_display")

    [[ -z "$choice" ]] && return

    local previous="$current"

    case "$choice" in
        "Deshabilitar Bordes Arcoíris")
            if [[ -f "$rainbow_script" ]]; then
                mv "$rainbow_script" "$disabled_sh_bak"
            fi
            current="disabled"
            if command -v hyprctl &>/dev/null; then
                hyprctl reload >/dev/null 2>&1 || true
            fi
            ;;
        "Color Wallust"|"Arcoíris Original"|"Flujo de Gradiente")
            local mode=""
            case "$choice" in
                "Color Wallust") mode="wallust_random" ;;
                "Arcoíris Original") mode="rainbow" ;;
                "Flujo de Gradiente") mode="gradient_flow" ;;
            esac
            # Ensure script is habilitado
            if [[ ! -f "$rainbow_script" ]]; then
                if   [[ -f "$disabled_sh_bak" ]]; then
                    mv "$disabled_sh_bak" "$rainbow_script"
                elif [[ -f "$disabled_bak_sh" ]]; then
                    mv "$disabled_bak_sh" "$rainbow_script"
                else
                    show_info "No se encontró el script RainbowBorders en $UserScripts."
                    return
                fi
            fi

            # Update EFFECT_TYPE in place; insert if missing
            if grep -q '^EFFECT_TYPE=' "$rainbow_script" 2>/dev/null; then
                sed -i 's/^EFFECT_TYPE=.*/EFFECT_TYPE="'"$mode"'"/' "$rainbow_script"
            else
                if head -n1 "$rainbow_script" | grep -q '^#!'; then
                    sed -i '1a EFFECT_TYPE="'"$mode"'"' "$rainbow_script"
                else
                    sed -i '1i EFFECT_TYPE="'"$mode"'"' "$rainbow_script"
                fi
            fi
            # Set current to chosen mode
            current="$mode"
            ;;
        *)
            return ;;
    esac

    # Run refresh if available
    if [[ -x "$refresh_script" ]]; then
        "$refresh_script" >/dev/null 2>&1 &
    fi

    # Apply mode immediately (in case refresh doesn't trigger it)
    if [[ "$current" != "disabled" && -x "$rainbow_script" ]]; then
        "$rainbow_script" >/dev/null 2>&1 &
    fi

    # No notifications; mode is shown in the menu
}

# Function to display the menu options without numbers
menu() {
    cat <<EOF
--- PERSONALIZACIONES DE USUARIO ---
Editar Valores por Defecto (Usuario)
Editar Atajos de Teclado (Usuario)
Editar Variables ENV (Usuario)
Editar Apps de Inicio (Capa Usuario)
Editar Reglas de Ventana (Capa Usuario)
Editar Ajustes de Sistema (Usuario)
Editar Decoraciones (Usuario)
Editar Animaciones (Usuario)
Editar Ajustes de Portátil (Usuario)
--- VALORES DEL SISTEMA ---
Editar Atajos del Sistema
Editar Apps de Inicio del Sistema
Editar Reglas de Ventana del Sistema
Editar Ajustes del Sistema
--- UTILIDADES ---
Configurar Fondo de SDDM
Elegir Tema de Terminal Kitty
Configurar Monitores (nwg-displays)
Configurar Reglas de Espacios (nwg-displays)
Ajustes GTK (nwg-look)
Ajustes Apps QT (qt6ct)
Ajustes Apps QT (qt5ct)
Elegir Animaciones de Hyprland
Elegir Perfiles de Monitor
Elegir Temas de Rofi
Buscar Atajos de Teclado
Alternar Modo de Juego
Cambiar Tema Claro-Oscuro
Modo de Bordes Arcoíris
EOF
}

# Main function to handle menu selection
main() {
    choice=$(menu | rofi -i -dmenu -config $rofi_theme -mesg "$msg")
    
    # Map choices to corresponding files
    case "$choice" in
    	"Editar Valores por Defecto (Usuario)") file="$UserConfigs/01-UserDefaults.conf" ;;
        "Editar Variables ENV (Usuario)") file="$UserConfigs/ENVariables.conf" ;;
        "Editar Atajos de Teclado (Usuario)") file="$UserConfigs/UserKeybinds.conf" ;;
        "Editar Apps de Inicio (Capa Usuario)") file="$UserConfigs/Startup_Apps.conf" ;;
        "Editar Reglas de Ventana (Capa Usuario)") file="$UserConfigs/WindowRules.conf" ;;
        "Editar Ajustes de Sistema (Usuario)") file="$configs/SystemSettings.conf"; show_info "Editando ajustes por defecto. Copia a UserConfigs/UserSettings.conf para sobrescribir." ;;
        "Editar Decoraciones (Usuario)") file="$UserConfigs/UserDecorations.conf" ;;
        "Editar Animaciones (Usuario)") file="$UserConfigs/UserAnimations.conf" ;;
        "Editar Ajustes de Portátil (Usuario)") file="$UserConfigs/Laptops.conf" ;;
        "Editar Atajos del Sistema") file="$configs/Keybinds.conf" ;;
        "Editar Apps de Inicio del Sistema") file="$configs/Startup_Apps.conf" ;;
        "Editar Reglas de Ventana del Sistema") file="$configs/WindowRules.conf" ;;
        "Editar Ajustes del Sistema") file="$configs/SystemSettings.conf" ;;
        "Configurar Fondo de SDDM") $scriptsDir/sddm_wallpaper.sh --normal ;;
        "Elegir Tema de Terminal Kitty") $scriptsDir/Kitty_themes.sh ;;
        "Configurar Monitores (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
        "Configurar Reglas de Espacios (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
		"Ajustes GTK (nwg-look)") 
            if ! command -v nwg-look &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-look first"
                exit 1
            fi
            nwg-look ;;
		"Ajustes Apps QT (qt6ct)") 
            if ! command -v qt6ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt6ct first"
                exit 1
            fi
            qt6ct ;;
		"Ajustes Apps QT (qt5ct)") 
            if ! command -v qt5ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt5ct first"
                exit 1
            fi
            qt5ct ;;
        "Elegir Animaciones de Hyprland") $scriptsDir/Animations.sh ;;
        "Elegir Perfiles de Monitor") $scriptsDir/MonitorProfiles.sh ;;
        "Elegir Temas de Rofi") $scriptsDir/RofiThemeSelector.sh ;;
        "Buscar Atajos de Teclado") $scriptsDir/KeyBinds.sh ;;
        "Alternar Modo de Juego") $scriptsDir/GameMode.sh ;;
        "Cambiar Tema Claro-Oscuro") $scriptsDir/DarkLight.sh ;;
        "Modo de Bordes Arcoíris") rainbow_borders_menu ;;
        *) return ;;  # Do nothing for invalid choices
    esac

    # Open the selected file in the terminal with the text editor
    if [ -n "$file" ]; then
        $term -e $edit "$file"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
