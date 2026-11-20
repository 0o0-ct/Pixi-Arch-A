#!/usr/bin/env bash
# Ayudantes para habilitar apps y selección de editor.

# Ayudante para añadir líneas exec-once de forma idempotente y segura
sa_append_once() {
    local file="$1"
    local line="$2"
    local present_re="${3:-}"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    # Normalizar \n final antes de añadir una exec-once nueva
    if [ -s "$file" ] && [ -n "$(tail -c 1 "$file" 2>/dev/null)" ]; then
        printf '\n' >>"$file"
    fi
    # Cadena fija: evita que el $ de $scriptsDir actúe como ancla de regex
    if [ -n "$present_re" ]; then
        grep -Eq -- "$present_re" "$file" && return 0
    elif grep -Fqx -- "$line" "$file"; then
        return 0
    fi
    printf '%s\n' "$line" >>"$file"
}

enable_ags() {
    local log="$1"
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"
    
    sa_append_once "$OVERLAY_SA" 'exec-once = ags' '^\s*exec-once\s*=\s*ags'
    sed -i '/#ags -q && ags &/s/^#//' "$HOME/.config/hypr/scripts/RefreshNoWaybar.sh"
    sed -i '/#ags -q && ags &/s/^#//' "$HOME/.config/hypr/scripts/Refresh.sh"
    echo "${INFO:-[INFO]} AGS habilitado en la configuración de aplicaciones" 2>&1 | tee -a "$log"
}

enable_quickshell() {
    local log="$1"
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"
    
    ensure_keybinds_init "$log"
    
    local line='exec-once = $scriptsDir/KeybindsLayoutInit.sh'
    if grep -Fqx -- "$line" "$OVERLAY_SA" 2>/dev/null; then
        return 0
    fi
    sa_append_once "$OVERLAY_SA" "$line"
    echo "${INFO:-[INFO]} KeybindsLayoutInit.sh añadido a la configuración de aplicaciones" 2>&1 | tee -a "$log"
}

ensure_keybinds_init() {
    local log="$1"
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"
    sa_append_once "$OVERLAY_SA" 'exec-once = $scriptsDir/KeybindsLayoutInit.sh' '^\s*exec-once\s*=\s*KeybindsLayoutInit'
}

enable_mouse_pointer() {
    local log="$1"
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"

    sa_append_once "$OVERLAY_SA" 'exec-once = $scriptsDir/MousePointer.sh' '^\s*exec-once\s*=\s*MousePointer'
    echo "${INFO:-[INFO]} Mouse pointer habilitado" 2>&1 | tee -a "$log"
}

enable_monitors() {
    local log="$1"
    local OVERLAY_SA="$HOME/.config/hypr/configs/Startup_Apps.conf"

    sa_append_once "$OVERLAY_SA" 'exec-once = $scriptsDir/monitor_setup.sh' '^\s*exec-once\s*=\s*monitor_setup'
    echo "${INFO:-[INFO]} Monitores habilitados" 2>&1 | tee -a "$log"
}

# Para actualizaciones futuras: 
# git ls-files -s Hyprland-Dots/scripts/lib_apps.sh | awk '{print $2}' | xargs -I{} sh -c 'git show {} > /dev/null'

# ASUS Linux (asusctl): configurar solo si está instalado; no fatal en otras laptops.
enable_asusctl() {
    local log="$1"
    if command -v asusctl >/dev/null 2>&1; then
        asusctl profile -P Balanced >/dev/null 2>&1 || true
        echo "${OK:-[OK]} ASUS Linux (asusctl) detectado y configurado." | tee -a "$log" 2>/dev/null || true
    else
        echo "${NOTE:-[NOTE]} asusctl no instalado; omitiendo configuración ASUS." 2>/dev/null || true
    fi
    return 0
}

# Editor por defecto: respeta $EDITOR; en installs no interactivos deja el
# fallback nano que ya define 01-UserDefaults.conf ($edit=${EDITOR:-nano}).
choose_default_editor() {
    local log="$1"
    local CONF="$HOME/.config/hypr/UserConfigs/01-UserDefaults.conf"
    [ -f "$CONF" ] || return 0
    if [ -n "${EDITOR:-}" ]; then
        sed -i "s|^#env = EDITOR,.*|env = EDITOR,${EDITOR}|" "$CONF"
        echo "${OK:-[OK]} Editor por defecto configurado: ${EDITOR}" | tee -a "$log" 2>/dev/null || true
    else
        echo "${NOTE:-[NOTE]} Sin EDITOR definido; usando nano como editor fallback." 2>/dev/null || true
    fi
    return 0
}
