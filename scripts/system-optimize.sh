#!/bin/bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 */  #
# System Optimization Script - Applies global optimizations for low resource usage
# Usage: bash scripts/system-optimize.sh

set -euo pipefail

echo "=== Applying System Optimizations ==="

# 1. Swappiness & VFS cache
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
sudo sysctl vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-swappiness.conf > /dev/null

# 2. Install ZRAM
sudo pacman -S --noconfirm zram-generator
echo '[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 60' | sudo tee /etc/systemd/zram-generator.conf > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now systemd-zram-setup@zram0.service

# 3. Enable NVIDIA Power Management
sudo systemctl enable --now nvidia-powerd.service

# 4. Set CPU Governor
echo 'GOVERNOR="schedutil"' | sudo tee /etc/default/cpufrequtils > /dev/null
sudo systemctl disable schedutil

# 5. Disable unnecessary services
sudo systemctl disable --now cups avahi-daemon modemmanager bluetooth
sudo systemctl disable --now apport popularity-contest
sudo systemctl disable --now unattended-upgrades
sudo systemctl disable --now snapd.service snapd.socket
sudo systemctl mask snapd.service snapd.socket

# 6. Set NVIDIA power limits
sudo nvidia-smi -pl 85
sudo nvidia-smi -ac 1320,1800

# 7. Kernel parameters
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_pstate=disable nowatchdog zswap.enabled=0 zswap.compressor=lz4 zswap.max_pool_percent=25"/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 8. Reload systemd
sudo systemctl daemon-reload

echo "=== System Optimization Complete ==="
echo "Note: Reboot required for kernel parameter changes to take effect"
