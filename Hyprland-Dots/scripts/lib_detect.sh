#!/usr/bin/env bash
# Detection and environment adjustment helpers shared by copy.sh.

# Nvidia tweaks: uncomments envs and adjusts hardware cursor setting.
detect_nvidia_adjust() {
  local log="$1"
  # Run GPU detection script to write envs to ~/.config/uwsm/env and ~/.config/hypr/configs/ENVariables_GPU.conf
  echo "${INFO:-[INFO]} Ejecutando detección automática de GPU..." 2>&1 | tee -a "$log" || true
  chmod +x "$HOME/.config/hypr/scripts/detect-gpu.sh"
  "$HOME/.config/hypr/scripts/detect-gpu.sh" 2>&1 | tee -a "$log" || true

  if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
    echo "${INFO:-[INFO]} GPU Nvidia detectada. Ajustando parámetros de cursor..." 2>&1 | tee -a "$log" || true
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' "$HOME/.config/hypr/configs/SystemSettings.conf"
  fi
}

# VM tweaks: enable software renderer envs and virtual monitor defaults.
detect_vm_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Chassis: vm'; then
    echo "${INFO:-[INFO]} El sistema se está ejecutando en una máquina virtual. Configurando variables y ajustes adecuados." 2>&1 | tee -a "$log" || true
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' "$HOME/.config/hypr/configs/SystemSettings.conf"
    sed -i '/env = WLR_RENDERER_ALLOW_SOFTWARE,1/s/^#//' "$HOME/.config/hypr/configs/ENVariables.conf"
    sed -i '/monitor = Virtual-1, 1920x1080@60,auto,1/s/^#//' "$HOME/.config/hypr/monitors.conf"
  fi
}

# NixOS tweaks: ensure polkit overlay is enabled and default disabled.
detect_nixos_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Operating System: NixOS'; then
    echo "${INFO:-[INFO]} Distribución NixOS detectada. Configurando variables y ajustes adecuados." 2>&1 | tee -a "$log" || true
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"
    local DISABLE_SA="$HOME/.config/hypr/configs/Startup_Apps.disable"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA" "$DISABLE_SA"
    grep -qx 'exec-once = $scriptsDir/Polkit-NixOS.sh' "$OVERLAY_SA" || echo 'exec-once = $scriptsDir/Polkit-NixOS.sh' >>"$OVERLAY_SA"
    grep -qx '\$scriptsDir/Polkit.sh' "$DISABLE_SA" || echo '$scriptsDir/Polkit.sh' >>"$DISABLE_SA"
  fi
}

# Decide waybar config/style based on chassis type. Echoes chosen config path.
detect_waybar_config() {
  if hostnamectl | grep -q 'Chassis: desktop'; then
    echo "desktop"
  else
    echo "laptop"
  fi
}

# Repara servicios de usuario que rompen el inicio de sesión con uwsm.
#
# uwsm aborta el arranque del compositor si encuentra graphical-session.target
# ya activo ("A compositor or graphical-session* target is already active!"),
# lo que deja al usuario en el greeter sin poder entrar al escritorio.
# Eso ocurre cuando una unidad habilitada en default.target.wants arrastra
# graphical-session.target (Wants=/Requires=), porque el gestor de usuario la
# arranca antes de que exista compositor.
#
# Para cada unidad afectada se: quita el enlace de default.target.wants,
# reancila la unidad en graphical-session.target y recarga systemd.
fix_uwsm_session_units() {
  local log="$1"
  local wants_dir="$HOME/.config/systemd/user/default.target.wants"

  [ -d "$wants_dir" ] || return 0
  command -v systemctl >/dev/null 2>&1 || return 0

  local link unit unit_file changed=0

  for link in "$wants_dir"/*; do
    [ -L "$link" ] || continue
    unit="$(basename "$link")"
    unit_file="$(readlink -f "$link" 2>/dev/null || true)"
    [ -n "$unit_file" ] && [ -f "$unit_file" ] || continue

    # Solo nos interesan las unidades que arrastran la sesión gráfica
    grep -Eq "^[[:space:]]*(Wants|Requires)=.*graphical-session\.target" "$unit_file" || continue

    echo "${WARN:-[WARN]} - $unit arrancaba antes del compositor y rompía el inicio de sesión (uwsm)." 2>&1 | tee -a "$log"

    # Quitar el enlace que la arrancaba desde default.target
    rm -f "$link"

    # Reanclar la unidad en graphical-session.target
    if grep -Eq "^[[:space:]]*WantedBy=default\.target" "$unit_file"; then
      sed -i "s/^\([[:space:]]*\)WantedBy=default\.target/\1WantedBy=graphical-session.target/" "$unit_file"
      systemctl --user daemon-reload 2>/dev/null || true
      systemctl --user enable "$unit" 2>/dev/null || true
      echo "${INFO:-[INFO]} - $unit re-anclada en graphical-session.target." 2>&1 | tee -a "$log"
    fi

    changed=1
  done

  [ "$changed" -eq 1 ] && systemctl --user daemon-reload 2>/dev/null || true
  return 0
}
