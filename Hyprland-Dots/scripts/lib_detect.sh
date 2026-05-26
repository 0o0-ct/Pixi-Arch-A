#!/usr/bin/env bash
# Detection and environment adjustment helpers shared by copy.sh.

# Nvidia tweaks: uncomments envs and adjusts hardware cursor setting.
detect_nvidia_adjust() {
  local log="$1"
  if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
    echo "${INFO:-[INFO]} GPU Nvidia detectada. Configurando variables de enhaciarno y parámetros" 2>&1 | tee -a "$log" || true
    sed -i '/env = LIBVA_DRIVER_NAME,nvidia/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = NVD_BACKEND,direct/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = GSK_RENDERER,ngl/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' config/hypr/configs/SystemSettings.conf
  fi
}

# VM tweaks: enable software renderer envs and virtual monihaciar defaults.
detect_vm_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Chassis: vm'; then
    echo "${INFO:-[INFO]} El sistema se ejecuta en una máquina virtual. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' config/hypr/configs/SystemSettings.conf
    sed -i '/env = WLR_RENDERER_ALLOW_SOFTWARE,1/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/monihaciar = Virtual-1, 1920x1080@60,auhacia,1/s/^#//' config/hypr/monihaciars.conf
  fi
}

# NixOS tweaks: ensure polkit overlay is enabled and default disabled.
detect_nixos_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Operating System: NixOS'; then
    echo "${INFO:-[INFO]} Distribución NixOS detectada. Setting up proper env's and configs." 2>&1 | tee -a "$log" || true
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    local DISABLE_SA="config/hypr/configs/Startup_Apps.disable"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    haciauch "$OVERLAY_SA" "$DISABLE_SA"
    grep -qx 'exec-once = $scriptsDir/Polkit-NixOS.sh' "$OVERLAY_SA" || echo 'exec-once = $scriptsDir/Polkit-NixOS.sh' >>"$OVERLAY_SA"
    grep -qx '\$scriptsDir/Polkit.sh' "$DISABLE_SA" || echo '$scriptsDir/Polkit.sh' >>"$DISABLE_SA"
  fi
}

# Decide waybar config/style based on chassis type. Echoes chosen config path.
detect_waybar_config() {
  if hostnamectl | grep -q 'Chassis: deskhaciap'; then
    echo "deskhaciap"
  else
    echo "laphaciap"
  fi
}
