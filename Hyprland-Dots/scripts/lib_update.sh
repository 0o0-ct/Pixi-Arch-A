#!/usr/bin/env bash

# run_repo_update
# Argumentos:
#   $1 - expected repository root (typically SCRIPT_DIR desde copy.sh)
# Behavior:
#   * Verifies the script is executed desde Hyprland-Dots root.
#   * Stashes local changes (including untracked), pulls latest changes.
#   * Shows progress, reports errors, and summarizes results.
#   * Waits for user input before returning control hacia caller.
run_repo_update() {
  local repo_dir="${1:-$(pwd)}"
  local expected_name="Hyprland-Dots"
  local log_dir="$repo_dir/Copy-Logs"
  local log_file="$log_dir/update-$(date +%d-%H%M%S)_git.log"

  mkdir -p "$log_dir"

  echo "${INFO} Iniciando actualización del repositorio..." | tee -a "$log_file"

  if [ ! -d "$repo_dir" ] || [ "$(basename "$repo_dir")" != "$expected_name" ]; then
    echo "${ERROR} Este asistente debe ejecutarse desde el directorio $expected_name. Actual: $(pwd)" | tee -a "$log_file"
    read -n1 -s -r -p "Presiona cualquier tecla para volver al menú..."
    echo
    return 1
  fi

  if [ "$PWD" != "$repo_dir" ]; then
    echo "${INFO} Cambiando de directorio a $repo_dir" | tee -a "$log_file"
    cd "$repo_dir" || {
      echo "${ERROR} Error al cambiar de directorio a $repo_dir" | tee -a "$log_file"
      read -n1 -s -r -p "Presiona cualquier tecla para volver al menú..."
      echo
      return 1
    }
  fi

  local head_before pull_status=0
  head_before=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  echo "${INFO} Forzando la rama main..." | tee -a "$log_file"
  git checkout -B main 2>&1 | tee -a "$log_file" || true
  git switch main 2>&1 | tee -a "$log_file" || true

  echo "${INFO} Descargando los últimos cambios desde origin/main..." | tee -a "$log_file"
  if git fetch origin main 2>&1 | tee -a "$log_file" && git reset --hard origin/main 2>&1 | tee -a "$log_file"; then
    pull_status=0
    echo "${OK} Repositorio actualizado correctamente." | tee -a "$log_file"
  else
    pull_status=$?
    echo "${ERROR} Error al actualizar (código de salida $pull_status)." | tee -a "$log_file"
  fi

  local head_after
  head_after=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  echo "----------------------------------------" | tee -a "$log_file"
  echo "Resumen:" | tee -a "$log_file"
  echo "  Repositorio : $repo_dir" | tee -a "$log_file"
  echo "  HEAD anterior: $head_before" | tee -a "$log_file"
  echo "  HEAD nuevo   : $head_after" | tee -a "$log_file"
  echo "  Estado Pull : $( [ $pull_status -eq 0 ] && echo "éxito" || echo "fallo" )" | tee -a "$log_file"
  echo "----------------------------------------" | tee -a "$log_file"

  # Also run the UserConfigs duplicate cleanup for existing installs,
  # using the same version gating as the main copy workflow (<= v2.3.19).
  if declare -f get_installed_dotfiles_version >/dev/null 2>&1 \
     && declare -f cleanup_duplicate_userconfigs >/dev/null 2>&1; then
    local installed_version
    installed_version=$(get_installed_dotfiles_version)
    if [ -n "$installed_version" ]; then
      echo "${INFO:-[INFO]} Buscando entradas duplicadas en UserConfigs tras la actualización del repositorio (detectada v$installed_version)..." | tee -a "$log_file"
      cleanup_duplicate_userconfigs "$installed_version" "$log_file"
    else
      echo "${NOTE:-[NOTE]} Omitiendo limpieza de duplicados en UserConfigs; no se detectó la versión." | tee -a "$log_file"
    fi
  fi

  read -n1 -s -r -p "Presiona cualquier tecla para volver al menú principal..."
  echo

  return $pull_status
}
