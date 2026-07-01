#!/bin/bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# System Optimization Script - Limpia, optimiza y mejora el rendimiento
# Uso: bash ~/.config/hypr/scripts/system-optimize.sh

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  💫 Pixi-Arch-A System Optimizer 💫              ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}${BOLD}▸ $1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

# Función para mostrar tamaño antes/después
show_freed() {
    local before=$1
    local after=$2
    local freed=$((before - after))
    if [ $freed -gt 0 ]; then
        if [ $freed -gt 1073741824 ]; then
            echo -e "  ${GREEN}→ Liberado: $(echo "scale=1; $freed/1073741824" | bc)GB${NC}"
        elif [ $freed -gt 1048576 ]; then
            echo -e "  ${GREEN}→ Liberado: $(echo "scale=1; $freed/1048576" | bc)MB${NC}"
        fi
    fi
}

print_header

# ═══════════════════════════════════════════
# 1. LIMPIEZA DE CACHES
# ═══════════════════════════════════════════
print_section "Limpieza de caches de usuario"

TOTAL_FREED=0

# Wallust cache (puede llegar a 15GB+)
if [ -d "$HOME/.cache/wallust" ]; then
    SIZE_BEFORE=$(du -sb "$HOME/.cache/wallust" 2>/dev/null | cut -f1 || echo 0)
    rm -rf "$HOME/.cache/wallust/"*
    SIZE_AFTER=$(du -sb "$HOME/.cache/wallust" 2>/dev/null | cut -f1 || echo 0)
    FREED=$((SIZE_BEFORE - SIZE_AFTER))
    TOTAL_FREED=$((TOTAL_FREED + FREED))
    print_ok "Cache wallust limpiado ($(echo "scale=1; $FREED/1073741824" | bc 2>/dev/null || echo '?')GB)"
fi

# Paru cache
if [ -d "$HOME/.cache/paru/clone" ]; then
    SIZE_BEFORE=$(du -sb "$HOME/.cache/paru" 2>/dev/null | cut -f1 || echo 0)
    rm -rf "$HOME/.cache/paru/clone/"*
    SIZE_AFTER=$(du -sb "$HOME/.cache/paru" 2>/dev/null | cut -f1 || echo 0)
    FREED=$((SIZE_BEFORE - SIZE_AFTER))
    TOTAL_FREED=$((TOTAL_FREED + FREED))
    print_ok "Cache paru limpiado ($(echo "scale=1; $FREED/1073741824" | bc 2>/dev/null || echo '?')GB)"
fi

# Yay cache
if [ -d "$HOME/.cache/yay" ]; then
    SIZE_BEFORE=$(du -sb "$HOME/.cache/yay" 2>/dev/null | cut -f1 || echo 0)
    rm -rf "$HOME/.cache/yay/"*
    SIZE_AFTER=$(du -sb "$HOME/.cache/yay" 2>/dev/null | cut -f1 || echo 0)
    FREED=$((SIZE_BEFORE - SIZE_AFTER))
    TOTAL_FREED=$((TOTAL_FREED + FREED))
    print_ok "Cache yay limpiado ($(echo "scale=1; $FREED/1073741824" | bc 2>/dev/null || echo '?')GB)"
fi

# Go build cache
if [ -d "$HOME/.cache/go-build" ]; then
    rm -rf "$HOME/.cache/go-build/"*
    print_ok "Cache go-build limpiado"
fi

# Thumbnails viejos (más de 30 días)
if [ -d "$HOME/.cache/thumbnails" ]; then
    find "$HOME/.cache/thumbnails" -type f -mtime +30 -delete 2>/dev/null
    print_ok "Thumbnails viejos limpiados (>30 días)"
fi

# Cliphist (clipboard history)
if [ -d "$HOME/.cache/cliphist" ]; then
    rm -rf "$HOME/.cache/cliphist/"*
    print_ok "Historial de clipboard limpiado"
fi

echo -e "\n  ${GREEN}${BOLD}Total espacio recuperado en caches: ~$(echo "scale=1; $TOTAL_FREED/1073741824" | bc 2>/dev/null || echo '?')GB${NC}"

# ═══════════════════════════════════════════
# 2. PACMAN CACHE
# ═══════════════════════════════════════════
print_section "Limpieza de cache de pacman"

if command -v paccache &>/dev/null; then
    # Mantener solo las 2 últimas versiones
    sudo paccache -r -k 2 2>/dev/null && print_ok "Cache de pacman limpiado (2 últimas versiones)" || print_warn "No se pudo limpiar cache de pacman (¿sudo?)"
else
    print_warn "paccache no encontrado (instalar pacman-contrib)"
fi

# ═══════════════════════════════════════════
# 3. PAQUETES HUÉRFANOS
# ═══════════════════════════════════════════
print_section "Paquetes huérfanos"

ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    ORPHAN_COUNT=$(echo "$ORPHANS" | wc -l)
    print_info "Encontrados $ORPHAN_COUNT paquetes huérfanos"
    
    echo -e "\n  ¿Deseas eliminarlos? (s/N): "
    read -r response
    if [[ "$response" =~ ^[sS]$ ]]; then
        echo "$ORPHANS" | sudo pacman -Rns - 2>/dev/null && print_ok "Paquetes huérfanos eliminados" || print_error "Error eliminando huérfanos"
    else
        print_info "Huérfanos no eliminados"
    fi
else
    print_ok "No hay paquetes huérfanos"
fi

# ═══════════════════════════════════════════
# 4. JOURNAL LOGS
# ═══════════════════════════════════════════
print_section "Limpieza de logs del journal"

JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' || echo "?")
print_info "Tamaño actual del journal: $JOURNAL_SIZE"

sudo journalctl --vacuum-time=7d 2>/dev/null && print_ok "Journal limpiado (mantener 7 días)" || print_warn "No se pudo limpiar journal (¿sudo?)"

# ═══════════════════════════════════════════
# 5. OPTIMIZACIÓN DE SWAPPINESS
# ═══════════════════════════════════════════
print_section "Optimización de memoria (swappiness)"

CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
print_info "Swappiness actual: $CURRENT_SWAPPINESS"

if [ "$CURRENT_SWAPPINESS" -gt 10 ]; then
    # Aplicar inmediatamente
    sudo sysctl vm.swappiness=10 2>/dev/null && print_ok "Swappiness cambiado a 10 (inmediato)" || print_warn "No se pudo cambiar swappiness"
    
    # Hacer persistente
    if ! grep -q "vm.swappiness" /etc/sysctl.d/99-swappiness.conf 2>/dev/null; then
        echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null 2>&1 && \
            print_ok "Swappiness persistente configurado (10)" || \
            print_warn "No se pudo hacer persistente"
    fi
else
    print_ok "Swappiness ya está optimizado ($CURRENT_SWAPPINESS)"
fi

# VFS cache pressure - mejora rendimiento de archivos
CURRENT_VCP=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "100")
if [ "$CURRENT_VCP" -gt 50 ]; then
    sudo sysctl vm.vfs_cache_pressure=50 2>/dev/null && print_ok "VFS cache pressure optimizado (50)" || true
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.d/99-swappiness.conf 2>/dev/null; then
        echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-swappiness.conf > /dev/null 2>&1 || true
    fi
fi

# ═══════════════════════════════════════════
# 6. ZRAM (SWAP COMPRIMIDA)
# ═══════════════════════════════════════════
print_section "Configuración de ZRAM"

if lsmod | grep -q zram 2>/dev/null || [ -e /dev/zram0 ]; then
    print_ok "ZRAM ya está activo"
    zramctl 2>/dev/null || true
else
    print_info "ZRAM no está activo"
    
    if command -v zramctl &>/dev/null; then
        echo -e "  ¿Deseas activar ZRAM? (swap comprimida en RAM, recomendado) (s/N): "
        read -r response
        if [[ "$response" =~ ^[sS]$ ]]; then
            # Calcular tamaño (25% de RAM o 8GB máximo)
            TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            ZRAM_SIZE_KB=$((TOTAL_RAM_KB / 4))
            MAX_ZRAM_KB=$((8 * 1024 * 1024))
            if [ $ZRAM_SIZE_KB -gt $MAX_ZRAM_KB ]; then
                ZRAM_SIZE_KB=$MAX_ZRAM_KB
            fi
            ZRAM_SIZE_MB=$((ZRAM_SIZE_KB / 1024))
            
            sudo modprobe zram 2>/dev/null
            if [ -e /dev/zram0 ]; then
                echo "${ZRAM_SIZE_MB}M" | sudo tee /sys/block/zram0/disksize > /dev/null 2>&1
                sudo mkswap /dev/zram0 > /dev/null 2>&1
                sudo swapon -p 100 /dev/zram0 2>/dev/null
                print_ok "ZRAM activado (${ZRAM_SIZE_MB}MB)"
                
                # Hacer persistente con systemd
                if ! systemctl is-enabled systemd-zram-setup@zram0.service &>/dev/null 2>&1; then
                    print_info "Para ZRAM persistente, instala: sudo pacman -S zram-generator"
                    print_info "Y configura /etc/systemd/zram-generator.conf"
                fi
            else
                print_error "No se pudo crear dispositivo ZRAM"
            fi
        fi
    else
        print_warn "zramctl no encontrado"
        print_info "Instalar: sudo pacman -S util-linux (ya debería estar)"
    fi
fi

# ═══════════════════════════════════════════
# 7. NVIDIA OPTIMIZACIÓN
# ═══════════════════════════════════════════
print_section "Optimización de NVIDIA"

if command -v nvidia-smi &>/dev/null; then
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo "?")
    GPU_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader 2>/dev/null || echo "?")
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null || echo "?")
    
    print_info "GPU: ${GPU_TEMP}°C | ${GPU_POWER} | Uso: ${GPU_UTIL}"
    
    # Verificar Dynamic Power Management
    if grep -q "NVreg_DynamicPowerManagement=0x02" /etc/modprobe.d/*.conf 2>/dev/null; then
        print_ok "Dynamic Power Management está activado (fine-grained)"
    else
        print_warn "Dynamic Power Management no configurado"
        print_info "Agregar a /etc/modprobe.d/nvidia.conf:"
        print_info "  options nvidia NVreg_DynamicPowerManagement=0x02"
    fi
    
    # Verificar runtime PM
    RUNTIME_STATUS=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo "unknown")
    if [ "$RUNTIME_STATUS" = "suspended" ]; then
        print_ok "GPU NVIDIA está suspendida (ahorro de energía)"
    elif [ "$RUNTIME_STATUS" = "active" ]; then
        print_warn "GPU NVIDIA está activa (consume energía)"
        print_info "Puede estar activa por el display manager (SDDM/Xorg)"
    fi
else
    print_info "NVIDIA no detectada"
fi

# ═══════════════════════════════════════════
# 8. POWER PROFILE
# ═══════════════════════════════════════════
print_section "Perfil de energía"

if command -v powerprofilesctl &>/dev/null; then
    CURRENT_PROFILE=$(powerprofilesctl get 2>/dev/null || echo "unknown")
    print_info "Perfil actual: $CURRENT_PROFILE"
    
    if [ "$CURRENT_PROFILE" != "balanced" ]; then
        print_warn "Perfil no es 'balanced'. Considera cambiarlo para equilibrar rendimiento/temperatura."
    else
        print_ok "Perfil balanceado activo"
    fi
fi

# ═══════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════
echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  📊 Resumen del Sistema                          ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"

echo -e "  ${BOLD}Disco:${NC}      $(df -h / | awk 'NR==2{print $3"/"$2" ("$5" usado)"}')"
echo -e "  ${BOLD}RAM:${NC}        $(free -h | awk 'NR==2{print $3"/"$2" usado"}')"
echo -e "  ${BOLD}Swap:${NC}       $(free -h | awk 'NR==3{print $3"/"$2" usado"}' || echo "Sin swap")"
echo -e "  ${BOLD}CPU Temp:${NC}   $(sensors 2>/dev/null | grep 'Package' | awk '{print $4}' || echo '?')"
echo -e "  ${BOLD}GPU Temp:${NC}   $(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo '?')°C"
echo -e "  ${BOLD}Procesos:${NC}   $(ps aux | wc -l)"
echo -e "  ${BOLD}Uptime:${NC}     $(uptime -p)"

echo -e "\n${GREEN}${BOLD}  ✨ ¡Optimización completada! ✨${NC}\n"
echo -e "  ${YELLOW}Nota: Reinicia la sesión para aplicar todos los cambios${NC}\n"
