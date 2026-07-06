#!/usr/bin/env bash
# Copy helpers split into phases to keep copy.sh lean.

copy_phase1() {
  local log="$1"
  local express_mode="${2:-0}"
  local dirs="fastfetch kitty rofi swaync"
  for DIR2 in $dirs; do
    local DIRPATH="$HOME/.config/$DIR2"
    if [ -d "$DIRPATH" ]; then
      if [ "$express_mode" -eq 1 ]; then
        BACKUP_DIR=$(get_backup_dirname)
        mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
        echo -e "${NOTE:-[NOTE]} Modo exprés: Se respaldó $DIR2 en $DIRPATH-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
        cp -r "config/$DIR2" "$HOME/.config/$DIR2" 2>&1 | tee -a "$log"
        echo -e "${OK:-[OK]} Modo exprés: ¡Se reemplazó $DIR2 con la nueva configuración!" 2>&1 | tee -a "$log"
        if [ "$DIR2" = "rofi" ]; then
          if [ -d "$DIRPATH-backup-$BACKUP_DIR/themes" ]; then
            for file in "$DIRPATH-backup-$BACKUP_DIR/themes"/*; do
              [ -e "$file" ] || continue
              cp -n "$file" "$HOME/.config/rofi/themes/" >>"$log" 2>&1 || true
            done || true
          fi
          if [ -f "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" ]; then
            cp "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" "$HOME/.config/rofi/0-shared-fonts.rasi" >>"$log" 2>&1
          fi
        fi
      else
        while true; do
          printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$DIR2${RESET:-} config found in ~/.config/\n"
          echo -n "${CAT:-[ACTION]} ¿Quieres reemplazar ${YELLOW:-}$DIR2${RESET:-} la configuración? (s/n): "
          read DIR1_CHOICE
          case "$DIR1_CHOICE" in
          [SsYy]*)
            BACKUP_DIR=$(get_backup_dirname)
            mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
            echo -e "${NOTE:-[NOTE]} - Se respaldó $DIR2 en $DIRPATH-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
            cp -r "config/$DIR2" "$HOME/.config/$DIR2" 2>&1 | tee -a "$log"
            echo -e "${OK:-[OK]} - ¡Se reemplazó $DIR2 con la nueva configuración!" 2>&1 | tee -a "$log"
            if [ "$DIR2" = "rofi" ]; then
              if [ -d "$DIRPATH-backup-$BACKUP_DIR/themes" ]; then
                for file in "$DIRPATH-backup-$BACKUP_DIR/themes"/*; do
                  [ -e "$file" ] || continue
                  cp -n "$file" "$HOME/.config/rofi/themes/" >>"$log" 2>&1 || true
                done || true
              fi
              if [ -f "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" ]; then
                cp "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" "$HOME/.config/rofi/0-shared-fonts.rasi" >>"$log" 2>&1
              fi
            fi
            break
            ;;
          [Nn]*)
            echo -e "${NOTE:-[NOTE]} - Omitiendo ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
            break
            ;;
          *) echo -e "${WARN:-[WARN]} - Elección no válida. Por favor introduce S o N." ;;
          esac
        done
      fi
    else
      cp -r "config/$DIR2" "$HOME/.config/$DIR2" 2>&1 | tee -a "$log"
      echo -e "${OK:-[OK]} - Copia completada para ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
    fi
  done
}

copy_waybar() {
  local log="$1"
  local express_mode="${2:-0}"
  local DIRW="waybar"
  local DIRPATHw="$HOME/.config/$DIRW"
  if [ -d "$DIRPATHw" ]; then
    if [ "$express_mode" -eq 1 ]; then
      BACKUP_DIR=$(get_backup_dirname)
      cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} Modo exprés: Se respaldó $DIRW en $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      rm -rf "$DIRPATHw" && cp -r "config/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
      for file in "config" "style.css"; do
        symlink="$DIRPATHw-backup-$BACKUP_DIR/$file"
        target_file="$DIRPATHw/$file"
        if [ -L "$symlink" ]; then
          symlink_target=$(readlink "$symlink")
          if [ -f "$symlink_target" ]; then
            rm -f "$target_file" && cp -f "$symlink_target" "$target_file"
          fi
        fi
      done
      for dir in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
        [ -e "$dir" ] || continue
        if [ -d "$dir" ]; then
          target_dir="$HOME/.config/waybar/configs/$(basename "$dir")"
          [ -d "$target_dir" ] || cp -r "$dir" "$HOME/.config/waybar/configs/"
        fi
      done
      for file in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
        [ -e "$file" ] || continue
        target_file="$HOME/.config/waybar/configs/$(basename "$file")"
        [ -e "$target_file" ] || cp "$file" "$HOME/.config/waybar/configs/"
      done || true
      for file in "$DIRPATHw-backup-$BACKUP_DIR/style"/*; do
        [ -e "$file" ] || continue
        if [ -d "$file" ]; then
          target_dir="$HOME/.config/waybar/style/$(basename "$file")"
          [ -d "$target_dir" ] || cp -r "$file" "$HOME/.config/waybar/style/"
        else
          target_file="$HOME/.config/waybar/style/$(basename "$file")"
          [ -e "$target_file" ] || cp "$file" "$HOME/.config/waybar/style/"
        fi
      done || true
      BACKUP_FILEw="$DIRPATHw-backup-$BACKUP_DIR/UserModules"
      [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$DIRPATHw/UserModules"
    else
      while true; do
        echo -n "${CAT:-[ACTION]} ¿Quieres reemplazar ${YELLOW:-}$DIRW${RESET:-} la configuración? (s/n): "
        read DIR1_CHOICE
        case "$DIR1_CHOICE" in
        [SsYy]*)
          BACKUP_DIR=$(get_backup_dirname)
          cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
          echo -e "${NOTE:-[NOTE]} - Se respaldó $DIRW en $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
          rm -rf "$DIRPATHw" && cp -r "config/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
          for file in "config" "style.css"; do
            symlink="$DIRPATHw-backup-$BACKUP_DIR/$file"
            target_file="$DIRPATHw/$file"
            if [ -L "$symlink" ]; then
              symlink_target=$(readlink "$symlink")
              if [ -f "$symlink_target" ]; then
                rm -f "$target_file" && cp -f "$symlink_target" "$target_file"
              fi
            fi
          done
          for dir in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
            [ -e "$dir" ] || continue
            if [ -d "$dir" ]; then
              target_dir="$HOME/.config/waybar/configs/$(basename "$dir")"
              [ -d "$target_dir" ] || cp -r "$dir" "$HOME/.config/waybar/configs/"
            fi
          done
          for file in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
            [ -e "$file" ] || continue
            target_file="$HOME/.config/waybar/configs/$(basename "$file")"
            [ -e "$target_file" ] || cp "$file" "$HOME/.config/waybar/configs/"
          done || true
          for file in "$DIRPATHw-backup-$BACKUP_DIR/style"/*; do
            [ -e "$file" ] || continue
            if [ -d "$file" ]; then
              target_dir="$HOME/.config/waybar/style/$(basename "$file")"
              [ -d "$target_dir" ] || cp -r "$file" "$HOME/.config/waybar/style/"
            else
              target_file="$HOME/.config/waybar/style/$(basename "$file")"
              [ -e "$target_file" ] || cp "$file" "$HOME/.config/waybar/style/"
            fi
          done || true
          BACKUP_FILEw="$DIRPATHw-backup-$BACKUP_DIR/UserModules"
          [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$DIRPATHw/UserModules"
          break
          ;;
        [Nn]*)
          echo -e "${NOTE:-[NOTE]} - Omitiendo el reemplazo de configuración de ${YELLOW:-}$DIRW${RESET:-}." 2>&1 | tee -a "$log"
          break
          ;;
        *) echo -e "${WARN:-[WARN]} - Elección no válida. Por favor introduce S o N." ;;
        esac
      done
    fi
  else
    cp -r "config/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Copia completada para ${YELLOW:-}$DIRW${RESET:-}" 2>&1 | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local DIR="ags btop cava hypr Kvantum qt5ct qt6ct swappy wallust wlogout"
  for DIR_NAME in $DIR; do
    local DIRPATH="$HOME/.config/$DIR_NAME"
    if [ -d "$DIRPATH" ]; then
      echo -e "\n${NOTE:-[NOTE]} - Se encontró la configuración para ${YELLOW:-}$DIR_NAME${RESET:-}, intentando respaldar."
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    fi
    if [ -d "config/$DIR_NAME" ]; then
      cp -r "config/$DIR_NAME/" "$HOME/.config/$DIR_NAME" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - ¡Copia de configuración para ${YELLOW:-}$DIR_NAME${RESET:-} completada!" 2>&1 | tee -a "$log"
    else
      echo "${ERROR:-[ERROR]} - El directorio config/$DIR_NAME no existe para ser copiado." 2>&1 | tee -a "$log"
    fi
  done
  
  # Copiar configuraciones de GTK3 y GTK4 (Nautilus & Portal Glass style)
  for GTK_DIR in gtk-3.0 gtk-4.0; do
    local GTK_PATH="$HOME/.config/$GTK_DIR"
    local SRC_GTK="../assets/$GTK_DIR" # Si se ejecuta desde Hyprland-Dots
    if [ ! -d "$SRC_GTK" ]; then
      SRC_GTK="assets/$GTK_DIR" # Si se ejecuta desde el directorio raíz
    fi
    if [ -d "$SRC_GTK" ]; then
      if [ -d "$GTK_PATH" ]; then
        echo -e "${NOTE:-[NOTE]} - Respaldando GTK config existente en $GTK_PATH."
        local BACK_DIR
        BACK_DIR=$(get_backup_dirname)
        mv "$GTK_PATH" "$GTK_PATH-backup-$BACK_DIR" 2>&1 | tee -a "$log"
      fi
      cp -r "$SRC_GTK/" "$HOME/.config/$GTK_DIR" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - ¡Copia de personalización para $GTK_DIR completada!" 2>&1 | tee -a "$log"
    fi
  done

  # Copiar configuración global de KDE (kdeglobals) para forzar modo oscuro en apps Qt Quick (ej. KDE Connect)
  local KDE_PATH="$HOME/.config/kdeglobals"
  local SRC_KDE="config/kdeglobals"
  if [ ! -f "$SRC_KDE" ]; then
    SRC_KDE="../config/kdeglobals" # Si se ejecuta desde subcarpeta
  fi
  if [ -f "$SRC_KDE" ]; then
    if [ -f "$KDE_PATH" ]; then
      echo -e "${NOTE:-[NOTE]} - Respaldando kdeglobals existente."
      local BACK_DIR
      BACK_DIR=$(get_backup_dirname)
      mv "$KDE_PATH" "$KDE_PATH-backup-$BACK_DIR" 2>&1 | tee -a "$log"
    fi
    cp "$SRC_KDE" "$KDE_PATH" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - ¡Copia de kdeglobals para modo oscuro completada!" 2>&1 | tee -a "$log"
  fi

  install_terminal_configs "$log"
}

# Restore Animations and Monitor Profiles plus key hypr files desde backup
restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"

  local HYPR_DIR="$HOME/.config/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_HYPR_PATH="$HYPR_DIR-backup-$BACKUP_DIR"

  if [ -d "$BACKUP_HYPR_PATH" ]; then
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Modo exprés: omitiendo la restauración automática de animaciones y perfiles de monitor." 2>&1 | tee -a "$log"
      return
    fi

    echo -e "\n${NOTE:-[NOTE]} Restaurando ${SKY_BLUE:-}animaciones y perfiles de monitor${RESET:-} en ${YELLOW:-}$HYPR_DIR${RESET:-}..."

    local DIR_B=("Monitor_Profiles" "animations" "wallpaper_effects")
    for DIR_RESTORE in "${DIR_B[@]}"; do
      local BACKUP_SUBDIR="$BACKUP_HYPR_PATH/$DIR_RESTORE"
      if [ -d "$BACKUP_SUBDIR" ]; then
        cp -r "$BACKUP_SUBDIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Directorio restaurado: ${MAGENTA:-}$DIR_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
      fi
    done

    local FILE_B=("monitors.conf" "workspaces.conf")
    for FILE_RESTORE in "${FILE_B[@]}"; do
      local BACKUP_FILE="$BACKUP_HYPR_PATH/$FILE_RESTORE"
      if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$HYPR_DIR/$FILE_RESTORE" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Archivo restaurado: ${MAGENTA:-}$FILE_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
      fi
    done
  fi
}

# Helper to extract overlay additions/disables desde previous user file vs base
compose_overlay_desde_backup() {
  local type="$1" # startup|windowrules
  local base_file="$2"
  local old_user_file="$3"
  local new_user_file="$4"
  local disable_file="$5"

  mkdir -p "$(dirname "$new_user_file")"
  : >"$new_user_file"
  : >"$disable_file"

  if [ "$type" = "startup" ]; then
    grep -E '^\s*exec-once\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.exec"
    grep -E '^\s*exec-once\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.exec"
    comm -23 "$old_user_file.tmp.exec" "$base_file.tmp.exec" >"$new_user_file"
    grep -E '^\s*#\s*exec-once\s*=' "$old_user_file" |
      sed -E 's/^\s*#\s*exec-once\s*=\s*//' |
      sed -E 's/^\s+//;s/\s+$//' |
      grep -Ev '^\$scriptsDir/KeybindsLayoutInit\.sh$' |
      sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.exec" "$base_file.tmp.exec"
  elif [ "$type" = "windowrules" ]; then
    grep -E '^(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.rules"
    grep -E '^(windowrule|layerrule)\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.rules"
    comm -23 "$old_user_file.tmp.rules" "$base_file.tmp.rules" >"$new_user_file"
    grep -E '^\s*#\s*(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s*#\s*//' | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.rules" "$base_file.tmp.rules"
  fi
}

cleanup_duplicate_userconfigs() {
  local current_version="$1"
  local log="$2"

  if [ -z "$current_version" ]; then
    return
  fi

  # Run de-dupe only for existing installs up hacia and including v2.3.19.
  # For v2.3.20 and newer, the underlying duplication bug is fixed and
  # this cleanup is no longer needed (and might mask future issues).
  if version_gte "$current_version" "2.3.20"; then
    echo "${INFO:-[INFO]} Omitiendo la limpieza de duplicados en UserConfigs para la versión detectada v$current_version (>= 2.3.20)." 2>&1 | tee -a "$log"
    return
  fi

  echo "${INFO:-[INFO]} Ejecutando la limpieza de duplicados en UserConfigs para la versión detectada v$current_version (<= 2.3.19)." 2>&1 | tee -a "$log"

  local HYPR_DIR="$HOME/.config/hypr"
  local BASE_DIR="$HYPR_DIR/configs"
  local USER_DIR="$HYPR_DIR/UserConfigs"

  local STARTUP_BASE="$BASE_DIR/Startup_Apps.conf"
  local STARTUP_USER="$USER_DIR/Startup_Apps.conf"
  local WINDOW_BASE="$BASE_DIR/WindowRules.conf"
  local WINDOW_USER="$USER_DIR/WindowRules.conf"
  local KEYBINDS_BASE="$BASE_DIR/Keybinds.conf"
  local KEYBINDS_USER="$USER_DIR/UserKeybinds.conf"

  # Startup_Apps: strip exec-once lines desde UserConfigs that are exact
  # duplicates of the base Startup_Apps.conf.
  if [ -f "$STARTUP_BASE" ] && [ -f "$STARTUP_USER" ]; then
    local tmp_startup
    local backup_startup
    backup_startup="$STARTUP_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_startup=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$STARTUP_BASE" "$STARTUP_USER" >"$tmp_startup"
    if ! cmp -s "$STARTUP_USER" "$tmp_startup"; then
      cp "$STARTUP_USER" "$backup_startup"
      mv "$tmp_startup" "$STARTUP_USER"
      echo "${NOTE:-[NOTE]} - Se eliminaron entradas duplicadas de Startup_Apps que coinciden con la configuración base." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_startup"
    fi
  fi

  # WindowRules: strip windowrule/layerrule lines desde UserConfigs that
  # are exact duplicates of the base WindowRules.conf.
  if [ -f "$WINDOW_BASE" ] && [ -f "$WINDOW_USER" ]; then
    local tmp_window
    local backup_window
    backup_window="$WINDOW_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_window=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$WINDOW_BASE" "$WINDOW_USER" >"$tmp_window"
    if ! cmp -s "$WINDOW_USER" "$tmp_window"; then
      cp "$WINDOW_USER" "$backup_window"
      mv "$tmp_window" "$WINDOW_USER"
      echo "${NOTE:-[NOTE]} - Se eliminaron entradas duplicadas de WindowRules que coinciden con la configuración base." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_window"
    fi
  fi

  # Keybinds: strip bind* lines desde UserKeybinds.conf that are exact
  # duplicates of the base Keybinds.conf. Comments and unbinds are kept.
  if [ -f "$KEYBINDS_BASE" ] && [ -f "$KEYBINDS_USER" ]; then
    local tmp_keybinds
    local backup_keybinds
    backup_keybinds="$KEYBINDS_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_keybinds=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        # Match any Hyprland bind variant: bindd, bindmd, bindld, binded,
        # bindlnd, bindeld, etc.
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$KEYBINDS_BASE" "$KEYBINDS_USER" >"$tmp_keybinds"
    if ! cmp -s "$KEYBINDS_USER" "$tmp_keybinds"; then
      cp "$KEYBINDS_USER" "$backup_keybinds"
      mv "$tmp_keybinds" "$KEYBINDS_USER"
      echo "${NOTE:-[NOTE]} - Se eliminaron entradas duplicadas de UserKeybinds que coinciden con la configuración base Keybinds.conf." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_keybinds"
    fi
  fi
}
restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"

  local DIRPATH="$HOME/.config/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH="$DIRPATH-backup-$BACKUP_DIR/UserConfigs"

  if [ -z "$BACKUP_DIR" ]; then
    echo "${ERROR:-[ERROR]} - El nombre del directorio de respaldo está vacío. Saliendo." 2>&1 | tee -a "$log"
    exit 1
  fi

  # In express mode we still want hacia run the de-dupe logic, but we skip
  # the interactive restoration prompts so the workflow stays non-blocking.
  local SKIP_RESTORE_PROMPTS=0
  if [ -d "$BACKUP_DIR_PATH" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Modo exprés: Restaurando automáticamente el directorio UserConfigs..." 2>&1 | tee -a "$log"
    rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - Directorio UserConfigs restaurado con éxito." 2>&1 | tee -a "$log"
    SKIP_RESTORE_PROMPTS=1
  fi

  if [ -d "$BACKUP_DIR_PATH" ] && [ "$SKIP_RESTORE_PROMPTS" -eq 0 ]; then
    local VERSION_FILE
    VERSION_FILE=$(find "$DIRPATH" -maxdepth 1 -name "v*.*.*" | head -n 1)
    local CURRENT_VERSION="999.9.9"
    if [ -n "$old_version" ]; then
      CURRENT_VERSION="$old_version"
    fi

    local TARGET_VERSION="2.3.19"

    echo -e "${NOTE:-[NOTE]} Restaurando configuraciones de usuario (User-Configs) anteriores... " 2>&1 | tee -a "$log"
    printf "${WARNING:-}\\
    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█\\n\\
            NOTES for RESTORING PREVIOUS CONFIGS\\n\\
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█\\n\\n\\
    The 'UserConfigs' directory is for all your personal settings.\\n\\
    Files in this directory will override the default configurations,\\n\\
    so your customizations are not lost when you update.\\n\\
" >&2

    if version_gte "$CURRENT_VERSION" "$TARGET_VERSION"; then
      read -r -p "${CAT:-[ACTION]} ¿Deseas restaurar tu directorio de UserConfigs anterior? (S/n): " restore_userconfigs_dir
      if [[ "$restore_userconfigs_dir" != [Nn]* ]]; then
        echo "${NOTE:-[NOTE]} Restaurando el directorio UserConfigs..." 2>&1 | tee -a "$log"
        rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Directorio UserConfigs restaurado con éxito." 2>&1 | tee -a "$log"
      else
        echo "${NOTE:-[NOTE]} - Restauración de UserConfigs omitida." 2>&1 | tee -a "$log"
      fi
    else
      echo -e "${NOTE:-[NOTE]} Versión detectada ${YELLOW:-}v$CURRENT_VERSION${RESET:-} (anterior a v$TARGET_VERSION). Usando modo de restauración heredado." 2>&1 | tee -a "$log"

      local FILES_TO_RESTORE=(
        "01-UserDefaults.conf"
        "ENVariables.conf"
        "LaptopDisplay.conf"
        "Laptops.conf"
        "Startup_Apps.conf"
        "UserDecorations.conf"
        "UserAnimations.conf"
        "UserKeybinds.conf"
        "UserSettings.conf"
        "WindowRules.conf"
      )

      for FILE_NAME in "${FILES_TO_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH/$FILE_NAME"
        if [ -f "$BACKUP_FILE" ]; then
          if [ "$FILE_NAME" = "Startup_Apps.conf" ]; then
            compose_overlay_desde_backup "startup" "$DIRPATH/configs/Startup_Apps.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/Startup_Apps.conf" "$DIRPATH/UserConfigs/Startup_Apps.disable"
            echo "${OK:-[OK]} - Capa migrada para ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi
          if [ "$FILE_NAME" = "WindowRules.conf" ]; then
            compose_overlay_desde_backup "windowrules" "$DIRPATH/configs/WindowRules.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/WindowRules.conf" "$DIRPATH/UserConfigs/WindowRules.disable"
            echo "${OK:-[OK]} - Capa migrada para ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi

          printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$FILE_NAME${RESET:-} in hypr backup...\n"
          read -r -p "${CAT:-[ACTION]} ¿Deseas restaurar ${YELLOW:-}$FILE_NAME${RESET:-} desde la copia de seguridad? (S/n): " file_restore

          if [[ "$file_restore" != [Nn]* ]]; then
            if cp "$BACKUP_FILE" "$DIRPATH/UserConfigs/$FILE_NAME"; then
              echo "${OK:-[OK]} - ¡$FILE_NAME restaurado!" 2>&1 | tee -a "$log"
            else
              echo "${ERROR:-[ERROR]} - ¡Error al restaurar $FILE_NAME!" 2>&1 | tee -a "$log"
            fi
          else
            echo "${NOTE:-[NOTE]} - Restauración de $FILE_NAME omitida." 2>&1 | tee -a "$log"
          fi
        fi
      done
    fi
  fi

  # Always run de-dupe based on the installed dotfiles version so that
  # express mode and standard mode behave consistently. Prefer the
  # pre-upgrade version (old_version) if provided so we still clean up
  # legacy duplicates when upgrading hacia a newer release that no longer
  # needs the fix.
  local detected_version="$old_version"
  if [ -z "$detected_version" ]; then
    detected_version=$(get_installed_dotfiles_version)
  fi
  if [ -n "$detected_version" ]; then
    cleanup_duplicate_userconfigs "$detected_version" "$log"
  fi
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"

  local DIRSHPATH="$HOME/.config/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_S="$DIRSHPATH-backup-$BACKUP_DIR/UserScripts"
  local SCRIPTS_TO_RESTORE=("RofiBeats.sh" "Weather.py" "Weather.sh")

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Modo exprés: Restaurando automáticamente los scripts de usuario..." 2>&1 | tee -a "$log"
    for SCRIPT_NAME in "${SCRIPTS_TO_RESTORE[@]}"; do
      local BACKUP_SCRIPT="$BACKUP_DIR_PATH_S/$SCRIPT_NAME"
      if [ -f "$BACKUP_SCRIPT" ]; then
        cp -f "$BACKUP_SCRIPT" "$DIRSHPATH/UserScripts/$SCRIPT_NAME" || true
      fi
    done
    return
  fi

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restaurando scripts de usuario (User-Scripts) anteriores..." 2>&1 | tee -a "$log"

    for SCRIPT_NAME in "${SCRIPTS_TO_RESTORE[@]}"; do
      local BACKUP_SCRIPT="$BACKUP_DIR_PATH_S/$SCRIPT_NAME"
      if [ -f "$BACKUP_SCRIPT" ]; then
        printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$SCRIPT_NAME${RESET:-} in hypr backup...\n"
        read -r -p "${CAT:-[ACTION]} ¿Deseas restaurar ${YELLOW:-}$SCRIPT_NAME${RESET:-} desde la copia de seguridad? (s/N): " script_restore

        if [[ "$script_restore" == [SsYy]* ]]; then
          if cp "$BACKUP_SCRIPT" "$DIRSHPATH/UserScripts/$SCRIPT_NAME"; then
            echo "${OK:-[OK]} - ¡$SCRIPT_NAME restaurado!" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - ¡Error al restaurar $SCRIPT_NAME!" 2>&1 | tee -a "$log"
          fi
        else
          echo "${NOTE:-[NOTE]} - Restauración de $SCRIPT_NAME omitida." 2>&1 | tee -a "$log"
        fi
      fi
    done
  fi
}

restore_hypr_files() {
  local log="$1"
  local express_mode="$2"

  local DIRPATH="$HOME/.config/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_F="$DIRPATH-backup-$BACKUP_DIR"
  local FILES_2_RESTORE=("hyprlock.conf" "hypridle.conf")

  if [ -d "$BACKUP_DIR_PATH_F" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Modo exprés: Restaurando automáticamente archivos individuales de hypr..." 2>&1 | tee -a "$log"
    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
      if [ -f "$BACKUP_FILE" ]; then
        cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE" || true
      fi
    done
    return
  fi

  if [ -d "$BACKUP_DIR_PATH_F" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restaurando algunos archivos en el directorio ${MAGENTA:-}$HOME/.config/hypr${RESET:-}..." 2>&1 | tee -a "$log"

    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
      if [ -f "$BACKUP_FILE" ]; then
        echo -e "\n${INFO:-[INFO]} Se encontró ${YELLOW:-}$FILE_RESTORE${RESET:-} en el respaldo de hypr..."
        read -r -p "${CAT:-[ACTION]} ¿Deseas restaurar ${YELLOW:-}$FILE_RESTORE${RESET:-} desde la copia de seguridad? (s/N): " file2restore

        if [[ "$file2restore" == [SsYy]* ]]; then
          if cp "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE"; then
            echo "${OK:-[OK]} - ¡$FILE_RESTORE restaurado!" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - ¡Error al restaurar $FILE_RESTORE!" 2>&1 | tee -a "$log"
          fi
        else
          echo "${NOTE:-[NOTE]} - Restauración de $FILE_RESTORE omitida." 2>&1 | tee -a "$log"
        fi
      else
        echo "${ERROR:-[ERROR]} - El archivo de respaldo $BACKUP_FILE no existe." 2>&1 | tee -a "$log"
      fi
    done
  fi
}
