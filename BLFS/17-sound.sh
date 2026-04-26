#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libsndfile"
    "check"
    "pulseaudio"
    "pavucontrol"
    "libnl"
    "alsa-lib"
    "alsa-utils"
    "17-pipewire"
    "lua"
    "apluse"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "Configuring Audio Groups..."
# 音声デバイスにアクセスするためのグループ設定
groupadd -f pulse
groupadd -f pulse-access
groupadd -f audio
usermod -aG audio,pulse,pulse-access $TARGET_USER

# /var/lib/alsa/asound.state作成
alsactl store

echo "===== ALSA & WirePlumber installation completed! ====="
echo "Next steps:"
echo "1. Run 'amixer sset Master unmute' to enable sound."
echo "2. Add 'exec wireplumber' to your sway config."
