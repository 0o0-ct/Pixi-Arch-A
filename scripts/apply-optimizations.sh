#!/bin/bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 */  #
# Auto-apply system optimizations on boot
# This script runs at startup to ensure optimizations are applied

set -euo pipefail

# Only run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

echo "Applying system optimizations..."

# 1. Swappiness
sysctl vm.swappiness=10 2>/dev/null || true

# 2. VFS cache pressure
sysctl vm.vfs_cache_pressure=50 2>/dev/null || true

# 3. NVIDIA power management (if available)
if systemctl is-enabled nvidia-powerd.service &>/dev/null; then
    nvidia-smi -pl 85 2>/dev/null || true
    nvidia-smi -ac 1320,1800 2>/dev/null || true
fi

# 4. CPU governor
echo 'GOVERNOR="schedutil"' > /etc/default/cpufrequtils 2>/dev/null || true

echo "Optimizations applied"