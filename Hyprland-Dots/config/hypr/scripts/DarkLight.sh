#!/usr/bin/env bash
## /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  ##
# For Dark and Light switching

# Add local bin to PATH for swww/awww compatibility
export PATH="$HOME/.local/bin:$PATH"

# Paths
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_base_path="$PICTURES_DIR/wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"
hypr_config_path="$HOME/.config/hypr"
swaync_style="$HOME/.config/swaync/style.css"
ags_style="$HOME/.config/ags/user/style.css"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/swaync/images/bell.png"
wallust_rofi="$HOME/.config/wallust/templates/colors-rofi.rasi"

kitty_conf="$HOME/.config/kitty/kitty.conf"

wallust_config="$HOME/.config/wallust/wallust.toml"
pallete_dark="dark16"
pallete_light="light16"
qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"

# intial kill process
for pid in waybar rofi swaync ags swaybg; do
    killall -SIGUSR1 "$pid"
done


# Initialize swww if needed
swww query || awww-daemon || swww-daemon

# Set swww options
swww="swww img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Force 100% Dark Mode
next_mode="Dark"
wallpaper_path="$dark_wallpapers"
qt5ct_color_scheme="$qt5ct_dark"
qt6ct_color_scheme="$qt6ct_dark"

# Function to update theme mode for the next cycle (always stays Dark)
update_theme_mode() {
    echo "Dark" > "$HOME/.cache/.theme_mode"
}

# Function to notify user
notify_user() {
    notify-send -u low -i "$notif" " Ciclando fondo de pantalla..." "Generando colores Dark Glass"
}

# Use sed to replace the palette setting in the wallust config file
sed -i 's/^palette = .*/palette = "'"$pallete_dark"'"/' "$wallust_config"

# Function to set Waybar style (Forzado Imperativo de Cristal Premium)
set_waybar_style() {
    theme="$1"
    waybar_styles="$HOME/.config/waybar/style"
    waybar_style_link="$HOME/.config/waybar/style.css"
    
    # Forzar si o si nuestro estilo Glass translúcido premium
    ln -sf "$waybar_styles/[Colored] Translucent.css" "$waybar_style_link"
    echo "Obligando al sistema a usar nuestro estilo Glass: [Colored] Translucent.css"
}

# Call the function after determining the mode
set_waybar_style "$next_mode"
notify_user "$next_mode"


# swaync color change (frosted glassmorphic style with blur compatibility)
if [ "$next_mode" = "Dark" ]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(15, 20, 30, 0.45);/' "${swaync_style}"
else
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.35);/' "${swaync_style}"
fi

# ags color change (frosted glassmorphic style with blur compatibility)
if command -v ags >/dev/null 2>&1; then    
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(15, 20, 30, 0.45);/' "${ags_style}"
	    sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.85);/' "${ags_style}" 
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${ags_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.35);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(15, 20, 30, 0.85);/' "${ags_style}"
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${ags_style}"
    fi
fi

# kitty background color change
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^foreground /s/^foreground .*/foreground #dddddd/' "${kitty_conf}"
	sed -i '/^background /s/^background .*/background #000000/' "${kitty_conf}"
	sed -i '/^cursor /s/^cursor .*/cursor #dddddd/' "${kitty_conf}"
else
	sed -i '/^foreground /s/^foreground .*/foreground #000000/' "${kitty_conf}"
	sed -i '/^background /s/^background .*/background #dddddd/' "${kitty_conf}"
	sed -i '/^cursor /s/^cursor .*/cursor #000000/' "${kitty_conf}"
fi

for pid_kitty in $(pidof kitty); do
    kill -SIGUSR1 "$pid_kitty"
done

# Set Dynamic Wallpaper for Dark or Light Mode (with safe fallback to preserve current wallpaper)
next_wallpaper=""
if [ -d "${dark_wallpapers}" ] && [ -d "${light_wallpapers}" ] && [ "$(find -L "${dark_wallpapers}" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
    if [ "$next_mode" = "Dark" ]; then
        next_wallpaper="$(find -L "${dark_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 2>/dev/null | shuf -n1 -z | xargs -0)"
    else
        next_wallpaper="$(find -L "${light_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 2>/dev/null | shuf -n1 -z | xargs -0)"
    fi
fi

# Safe Fallback: if dynamic wallpaper is empty or folder doesn't exist, preserve current active wallpaper
if [ -z "${next_wallpaper}" ] || [ ! -f "${next_wallpaper}" ]; then
    if [ -f "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current" ]; then
        next_wallpaper="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    elif [ -L "$HOME/.config/rofi/.current_wallpaper" ]; then
        next_wallpaper=$(readlink -f "$HOME/.config/rofi/.current_wallpaper")
    else
        # Find any static wallpaper in pictures directory (including Spanish locale and all image types)
        next_wallpaper=$(find -L "$HOME/Imágenes/wallpapers" "$HOME/Pictures/wallpapers" "$PICTURES_DIR/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)
    fi
fi

# Update wallpaper using swww command safely
if [ -n "${next_wallpaper}" ] && [ -f "${next_wallpaper}" ]; then
    $swww "${next_wallpaper}" $effect
    # Ensure current wallpaper cache file is updated
    mkdir -p "$(dirname "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current")"
    echo "${next_wallpaper}" > "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    ln -sf "${next_wallpaper}" "$HOME/.config/rofi/.current_wallpaper" || true
else
    echo "No wallpaper file found to apply."
fi


# Set Kvantum Manager theme & QT5/QT6 settings
if [ "$next_mode" = "Dark" ]; then
    kvantum_theme="catppuccin-mocha-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
else
    kvantum_theme="catppuccin-latte-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"
fi

sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "$HOME/.config/qt5ct/qt5ct.conf"
sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "$HOME/.config/qt6ct/qt6ct.conf"
kvantummanager --set "$kvantum_theme"


# set the rofi color for background (frosted glassmorphic style with blur compatibility)
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^background:/s/.*/background: rgba(15, 20, 30, 0.45);/' "$wallust_rofi"
else
    sed -i '/^background:/s/.*/background: rgba(255, 255, 255, 0.35);/' "$wallust_rofi"
fi


# GTK themes and icons switching
set_custom_gtk_theme() {
    mode=$1
    color_setting="org.gnome.desktop.interface color-scheme"
    theme_setting="org.gnome.desktop.interface gtk-theme"
    icon_setting="org.gnome.desktop.interface icon-theme"

    # Get current theme and icon settings directly from settings.ini (source of truth)
    settings_file="$HOME/.config/gtk-3.0/settings.ini"
    current_theme=""
    current_icon=""
    if [ -f "$settings_file" ]; then
        current_theme=$(grep -E "^\s*gtk-theme-name\s*=" "$settings_file" | cut -d'=' -f2 | tr -d "'\" ")
        current_icon=$(grep -E "^\s*gtk-icon-theme-name\s*=" "$settings_file" | cut -d'=' -f2 | tr -d "'\" ")
    fi

    # Fallback to gsettings if settings.ini has nothing or doesn't exist
    if [ -z "$current_theme" ]; then
        current_theme=$(gsettings get $theme_setting | tr -d "'")
    fi
    if [ -z "$current_icon" ]; then
        current_icon=$(gsettings get $icon_setting | tr -d "'")
    fi

    if [ "$mode" == "Light" ]; then
        gsettings set $color_setting 'prefer-light'
        # Swap current theme's Dark variant to Light variant
        new_theme="${current_theme/Dark/Light}"
        new_theme="${new_theme/dark/light}"
        new_icon="${current_icon/Dark/Light}"
        new_icon="${new_icon/dark/light}"
    else
        gsettings set $color_setting 'prefer-dark'
        # Swap current theme's Light variant to Dark variant
        new_theme="${current_theme/Light/Dark}"
        new_theme="${new_theme/light/dark}"
        new_icon="${current_icon/Light/Dark}"
        new_icon="${new_icon/light/dark}"
    fi

    # Fallback to random theme/icon ONLY if the swapped counterpart directory does not exist
    if [ ! -d "$HOME/.themes/$new_theme" ] && [ ! -d "/usr/share/themes/$new_theme" ]; then
        echo "GTK theme counterpart $new_theme not found, searching folder..."
        gtk_themes_directory="$HOME/.themes"
        search_keywords="*${mode}*"
        themes=()
        while IFS= read -r -d '' theme_search; do
            themes+=("$(basename "$theme_search")")
        done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0 2>/dev/null)
        if [ ${#themes[@]} -gt 0 ]; then
            new_theme=${themes[RANDOM % ${#themes[@]}]}
        else
            new_theme="$current_theme"
        fi
    fi

    if [ ! -d "$HOME/.icons/$new_icon" ] && [ ! -d "/usr/share/icons/$new_icon" ]; then
        echo "Icon theme counterpart $new_icon not found, searching folder..."
        icon_directory="$HOME/.icons"
        search_keywords="*${mode}*"
        icons=()
        while IFS= read -r -d '' icon_search; do
            icons+=("$(basename "$icon_search")")
        done < <(find "$icon_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0 2>/dev/null)
        if [ ${#icons[@]} -gt 0 ]; then
            new_icon=${icons[RANDOM % ${#icons[@]}]}
        else
            new_icon="$current_icon"
        fi
    fi

    # Set new theme in gsettings & settings.ini
    echo "Applying GTK theme for $mode: $new_theme"
    gsettings set $theme_setting "$new_theme"
    if [ -f "$settings_file" ]; then
        sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$new_theme|" "$settings_file"
    fi
    settings_file_4="$HOME/.config/gtk-4.0/settings.ini"
    if [ -f "$settings_file_4" ]; then
        sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$new_theme|" "$settings_file_4"
    fi

    if command -v flatpak &> /dev/null; then
        flatpak --user override --filesystem=$HOME/.themes || true
        sleep 0.2
        flatpak --user override --env=GTK_THEME="$new_theme" || true
    fi

    # Set new icon in gsettings & settings.ini
    echo "Applying Icon theme for $mode: $new_icon"
    gsettings set $icon_setting "$new_icon"
    if [ -f "$settings_file" ]; then
        sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$new_icon|" "$settings_file"
    fi
    if [ -f "$settings_file_4" ]; then
        sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$new_icon|" "$settings_file_4"
    fi

    [ -f "$HOME/.config/qt5ct/qt5ct.conf" ] && sed -i "s|^icon_theme=.*$|icon_theme=$new_icon|" "$HOME/.config/qt5ct/qt5ct.conf" || true
    [ -f "$HOME/.config/qt6ct/qt6ct.conf" ] && sed -i "s|^icon_theme=.*$|icon_theme=$new_icon|" "$HOME/.config/qt6ct/qt6ct.conf" || true
    if command -v flatpak &> /dev/null; then
        flatpak --user override --filesystem=$HOME/.icons || true
        sleep 0.2
        flatpak --user override --env=ICON_THEME="$new_icon" || true
    fi
}

# Call the function to set GTK theme and icon theme based on mode
set_custom_gtk_theme "$next_mode"

# Update theme mode for the next cycle
update_theme_mode


${SCRIPTSDIR}/WallustSwww.sh &&

sleep 2
# kill process
for pid1 in waybar rofi swaync ags swaybg; do
    killall "$pid1"
done

sleep 1
${SCRIPTSDIR}/Refresh.sh 

sleep 0.5
# Display notifications for theme and icon changes 
notify-send -u low -i "$notif" " Fondo y Colores Glass:" "¡Regenerados con Éxito!"

exit 0

