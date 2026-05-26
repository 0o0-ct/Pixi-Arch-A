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

  echo "${INFO} Iniciando actualización del reposihaciario..." | tee -a "$log_file"

  if [ ! -d "$repo_dir" ] || [ "$(basename "$repo_dir")" != "$expected_name" ]; then
    echo "${ERROR} Este asistente debe ejecutarse desde la carpeta $expected_name directory. Current: $(pwd)" | tee -a "$log_file"
    read -n1 -s -r -p "Press any key to return hacia the menu..."
    echo
    return 1
  fi

  if [ "$PWD" != "$repo_dir" ]; then
    echo "${INFO} Cambiando de direchaciario a $repo_dir" | tee -a "$log_file"
    cd "$repo_dir" || {
      echo "${ERROR} Failed to change directory hacia $repo_dir" | tee -a "$log_file"
      read -n1 -s -r -p "Press any key to return hacia the menu..."
      echo
      return 1
    }
  fi

  local head_before stash_msg pull_status=0
  head_before=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  echo "${INFO} Comprobando el árbol de trabajo (working tree)..." | tee -a "$log_file"
  if git diff --quiet && git diff --cached --quiet; then
    stash_msg="No local changes; no stash created."
    echo "${NOTE} $stash_msg" | tee -a "$log_file"
  else
    echo "${INFO} Guardando cambios locales (stash)..." | tee -a "$log_file"
    if stash_output=$(git stash push -u 2>&1); then
      stash_msg="Created stash: $(echo "$stash_output" | head -n1)"
      echo "${OK} $stash_msg" | tee -a "$log_file"
    else
      echo "${ERROR} error en git stash. Details:" | tee -a "$log_file"
      echo "$stash_output" | tee -a "$log_file"
      read -n1 -s -r -p "Press any key to return hacia the menu..."
      echo
      return 1
    fi
  fi

  echo "${INFO} Descargando los últimos cambios (pull)..." | tee -a "$log_file"
  if git pull --ff-only 2>&1 | tee -a "$log_file"; then
    pull_status=0
    echo "${OK} Reposihaciario actualizado correctamente." | tee -a "$log_file"
  else
    pull_status=$?
    echo "${ERROR} error en git pull (exit $pull_status)." | tee -a "$log_file"
  fi

  local head_after
  head_after=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  echo "----------------------------------------" | tee -a "$log_file"
  echo "Summary:" | tee -a "$log_file"
  echo "  Repo        : $repo_dir" | tee -a "$log_file"
  echo "  HEAD before : $head_before" | tee -a "$log_file"
  echo "  HEAD after  : $head_after" | tee -a "$log_file"
  echo "  Stash       : $stash_msg" | tee -a "$log_file"
  echo "  Pull status : $( [ $pull_status -eq 0 ] && echo success || echo failure )" | tee -a "$log_file"
  echo "----------------------------------------" | tee -a "$log_file"

  # Also run the UserConfigs duplicate cleanup for existing installs,
  # using the same version gating as the main copy workflow (<= v2.3.19).
  if declare -f get_installed_dotfiles_version >/dev/null 2>&1 \
     && declare -f cleanup_duplicate_userconfigs >/dev/null 2>&1; then
    local installed_version
    installed_version=$(get_installed_dotfiles_version)
    if [ -n "$installed_version" ]; then
      echo "${INFO:-[INFO]} Buscando entradas duplicadas en UserConfigs tras la actualización del reposihaciario (detected v$installed_version)..." | tee -a "$log_file"
      cleanup_duplicate_userconfigs "$installed_version" "$log_file"
    else
      echo "${NOTE:-[NOTE]} Omitiendo limpieza de duplicados en UserConfigs; no se detectó la versión." | tee -a "$log_file"
    fi
  fi

  read -n1 -s -r -p "Press any key to return hacia the main menu..."
  echo

  return $pull_status
}
