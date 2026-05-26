#!/usr/bin/env bash

# show_copy_menu
# Argumentos:
#   $1 - express_supported flag (1 if available, 0 otherwise)
# Configura la variable global COPY_MENU_CHOICE hacia one of: install, upgrade, express, quit
show_copy_menu() {
  local express_supported="${1:-0}"
  local menu_title="      KooL's Hyprland Dotfiles      "
  local prompt="Selecciona lo que te gustaría hacer:"

  local install_tag="Instalar"
  local upgrade_tag="Actualizar"
  local express_tag="Exprés"
  local update_tag="ActualizarRepo"
  local quit_tag="Salir"

  local install_desc="Copia limpia y nueva"
  local upgrade_desc="Respaldos + preguntas interacticas"
  local express_desc="Omite restauraciones y fondos adicionales"
  local update_desc="Guardar cambios locales + git pull"
  local quit_desc="Salir sin realizar cambios"

  local choice=""
  run_basic_menu() {
    while true; do
      printf "\n%s\n" "$menu_title"
      printf "%s\n" "$prompt"
      printf "  1) Instalar - %s\n" "$install_desc"
      printf "  2) Actualizar - %s\n" "$upgrade_desc"
      if [ "$express_supported" -eq 1 ]; then
        printf "  3) Exprés - %s\n" "$express_desc"
      else
        printf "  3) Exprés - %s (desactivado)\n" "$express_desc"
      fi
      printf "  4) ActualizarRepo - %s\n" "$update_desc"
      printf "  5) Salir - %s\n" "$quit_desc"
      printf "Introduce tu elección [1-5]: "
      read -r text_choice
      case "$text_choice" in
      1) choice="$install_tag"; break ;;
      2) choice="$upgrade_tag"; break ;;
      3)
        if [ "$express_supported" -eq 1 ]; then
          choice="$express_tag"
          break
        else
          echo "La instalación rápida (Express) está desactivada en este sistema."
        fi
        ;;
      4) choice="$update_tag"; break ;;
      5) choice="$quit_tag"; break ;;
      *) echo "Selección inválida. Por favor elige 1-5." ;;
      esac
    done
  }

  if [ "$COPY_TUI_BACKEND" = "basic" ]; then
    run_basic_menu
      case "$choice" in
    "Instalar"|"Install"|"install") choice="install" ;;
    "Actualizar"|"Upgrade"|"upgrade") choice="upgrade" ;;
    "Exprés"|"Express"|"express") choice="express" ;;
    "ActualizarRepo"|"Update"|"update") choice="update" ;;
    "Salir"|"Quit"|"quit") choice="quit" ;;
  esac
  COPY_MENU_CHOICE="$choice"

    return 0
  fi

  # Fallback hacia whiptail if present
  if command -v whiptail >/dev/null 2>&1; then
    if ! choice=$(whiptail --title "$menu_title" --menu "$prompt" 17 60 8 \
      "$install_tag" "$install_desc" \
      "$upgrade_tag" "$upgrade_desc" \
      "$express_tag" "$express_desc" \
      "$update_tag" "$update_desc" \
      "$quit_tag" "$quit_desc" 3>&1 1>&2 2>&3); then
      COPY_MENU_CHOICE="quit"
      return 1
    fi
  else
    # Alternativa en texto plano
    run_basic_menu
  fi

  # shellcheck disable=SC2034  # used by parent script after sourcing this file
    case "$choice" in
    "Instalar"|"Install"|"install") choice="install" ;;
    "Actualizar"|"Upgrade"|"upgrade") choice="upgrade" ;;
    "Exprés"|"Express"|"express") choice="express" ;;
    "ActualizarRepo"|"Update"|"update") choice="update" ;;
    "Salir"|"Quit"|"quit") choice="quit" ;;
  esac
  COPY_MENU_CHOICE="$choice"

}
