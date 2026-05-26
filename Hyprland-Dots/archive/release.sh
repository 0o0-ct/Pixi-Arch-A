#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# For downloading dots from releases

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

# Check /etc/os-release for Ubuntu or Debian and warn about Hyprland version requirement
if grep -iqE '^(ID_LIKE|ID)=.*(ubuntu|debian)' /etc/os-release >/dev/null 2>&1; then
  printf "\n%.0s" {1..1}
  echo "${WARNING} These Dotfiles are only supported on Hyprland 0.51.1 or greater. Do not install on older revisions.${RESET}"
  while true; do
    echo -n "${CAT} Do you want to continue anyway? (y/N): ${RESET}"
    read _continue
    _continue=$(echo "${_continue}" | tr '[:upper:]' '[:lower:]')
    case "${_continue}" in
      y|yes)
        echo "${NOTE} Proceeding on Ubuntu/Debian by user confirmation." 
        break
        ;;
      n|no|"")
        printf "\n%.0s" {1..1}
        echo "${INFO} Cancelando por elección del usuario. No se hicieron cambios." 
        printf "\n%.0s" {1..1}
        exit 1
        ;;
      *)
        echo "${WARN} Por favor responde 's' o 'n'." 
        ;;
    esac
  done
fi


printf "\n%.0s" {1..1}  
echo -e "\e[35m
    ╦╔═┌─┐┌─┐╦    ╔╦╗┌─┐┌┬┐┌─┐
    ╠╩╗│ ││ │║     ║║│ │ │ └─┐ 2025
    ╩ ╩└─┘└─┘╩═╝  ═╩╝└─┘ ┴ └─┘ release.sh
\e[0m"
printf "\n%.0s" {1..1}  

echo "${WARNING}¡ A T E N C I Ó N !${RESET}"
echo "${SKY_BLUE}Este script está diseñado para descargar desde los "RELEASES" (Versiones) de Pixi-Arch-A${RESET}"
echo "${YELLOW}Ten en cuenta que los RELEASES suelen ser una versión más antigua que la rama principal (main)${RESET}"
printf "\n%.0s" {1..1}
echo "${MAGENTA}Si deseas obtener la versión más reciente, por favor ejecuta ${SKY_BLUE}copy.sh${RESET} ${MAGENTA}instead${RESET}"
printf "\n%.0s" {1..1}
read -p "${CAT} - ¿Te gustaría proceder e instalar desde los releases? (s/n): ${RESET}" proceed

if [ "$proceed" != "y" ]; then
    printf "\n%.0s" {1..1}
    echo "${INFO} Instalación cancelada. ${SKY_BLUE}Sin cambios en tu sistema.${RESET} ${YELLOW}¡Adiós!${RESET}"
    printf "\n%.0s" {1..1}
    exit 1
fi

printf "${NOTE} Descargando / Comprobando si existe Hyprland-Dots.tar.gz...\n"

# Check if Hyprland-Dots.tar.gz exists
if [ -f Hyprland-Dots.tar.gz ]; then
  printf "${NOTE} Hyprland-Dots.tar.gz encontrado.\n"

  # Get the version from the existing tarball filename
  existing_version=$(echo Hyprland-Dots.tar.gz | grep -oP 'v\d+\.\d+\.\d+' | sed 's/v//')

  # Fetch the tag_name for the latest release using the GitHub API
  latest_version=$(curl -s https://api.github.com/repos/0o0-ct/Pixi-Arch-A/Hyprland-Dots/releases/latest | grep "tag_name" | cut -d '"' -f 4 | sed 's/v//')

  # Check if versions match
  if [ "$existing_version" = "$latest_version" ]; then
    echo -e "${OK} Hyprland-Dots.tar.gz is up-to-date with the latest release ($latest_version)."
    
    # Sleep for 10 seconds before exiting
    printf "${NOTE} No update encontrado. Sleeping for 10 seconds...\n"
    sleep 10
    exit 0
  else
    echo -e "${WARN} Hyprland-Dots.tar.gz is outdated (Existing version: $existing_version, Latest version: $latest_version)."
    read -p "Do you want to upgrade to the latest version? (y/n): " upgrade_choice
    if [ "$upgrade_choice" = "y" ]; then
		echo -e "${NOTE} Proceeding to download the latest release."
		
		# Delete existing directories starting with 0o0-ct/Pixi-Arch-A-Hyprland-Dots
      find . -type d -name '0o0-ct/Pixi-Arch-A-Hyprland-Dots*' -exec rm -rf {} +
      rm -f Hyprland-Dots.tar.gz
      printf "${WARN} Removed existing Hyprland-Dots.tar.gz.\n"
    else
      echo -e "${NOTE} User chose not to upgrade. Exiting..."
      exit 0
    fi
  fi
fi

printf "${NOTE} Downloading the latest Hyprland source code release...\n"

# Fetch the tag name for the latest release using the GitHub API
latest_tag=$(curl -s https://api.github.com/repos/0o0-ct/Pixi-Arch-A/Hyprland-Dots/releases/latest | grep "tag_name" | cut -d '"' -f 4)

# Check if the tag is obtained successfully
if [ -z "$latest_tag" ]; then
  echo -e "${ERROR} Unable to fetch the latest tag information."
  exit 1
fi

# Fetch the tarball URL for the latest release using the GitHub API
latest_tarball_url=$(curl -s https://api.github.com/repos/0o0-ct/Pixi-Arch-A/Hyprland-Dots/releases/latest | grep "tarball_url" | cut -d '"' -f 4)

# Check if the URL is obtained successfully
if [ -z "$latest_tarball_url" ]; then
  echo -e "${ERROR} Unable to fetch the tarball URL for the latest release."
  exit 1
fi

# Get the filename from the URL and include the tag name in the file name
file_name="Hyprland-Dots-${latest_tag}.tar.gz"

# Download the latest release source code tarball to the current directory
if curl -L "$latest_tarball_url" -o "$file_name"; then
  # Extract the contents of the tarball
  tar -xzf "$file_name" || exit 1

  # delete existing Hyprland-Dots
  rm -rf 0o0-ct/Pixi-Arch-A-Hyprland-Dots

  # Identify the extracted directory
  extracted_directory=$(tar -tf "$file_name" | grep -o '^[^/]\+' | uniq)

  # Rename the extracted directory to 0o0-ct/Pixi-Arch-A-Hyprland-Dots
  mv "$extracted_directory" 0o0-ct/Pixi-Arch-A-Hyprland-Dots || exit 1

  cd "0o0-ct/Pixi-Arch-A-Hyprland-Dots" || exit 1

  # Set execute permission for copy.sh and execute it
  chmod +x copy.sh
  ./copy.sh 2>&1 | tee -a "../install-$(date +'%d-%H%M%S')_dots.log"

  echo -e "${OK} Latest source code release downloaded, extracted, and processed successfully."
else
  echo -e "${ERROR} Failed to download the latest source code release."
  exit 1
fi
