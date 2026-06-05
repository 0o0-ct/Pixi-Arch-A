#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Script to randomly select a wallpaper and set it as the SDDM login screen background

wallDIR="$HOME/Imágenes/wallpapers"
sddm_target="/usr/share/sddm/themes/simple_sddm_2/Backgrounds/default"

# Verify that wallpapers directory exists
if [ ! -d "$wallDIR" ]; then
    echo "Directory $wallDIR does not exist."
    exit 1
fi

# Find all image files in the wallpapers directory
mapfile -d '' PICS < <(find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0)

# Check if any images were found
if [ ${#PICS[@]} -eq 0 ]; then
    echo "No wallpapers found in $wallDIR."
    exit 1
fi

# Select a random wallpaper
RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"

# Copy the selected wallpaper to the SDDM background path
if cp -f "$RANDOM_PIC" "$sddm_target"; then
    echo "Successfully set SDDM background to: $(basename "$RANDOM_PIC")"
else
    echo "Failed to copy wallpaper to SDDM target. Check permissions."
    exit 1
fi
