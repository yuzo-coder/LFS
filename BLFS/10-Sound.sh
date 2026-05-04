#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libogg
libvorbis
libsndfile
alsa-lib
alsa-utils

pipewire
wireplumber
pulseaudio
pavucontrol
rtkit
libcanberra

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


groupadd -f pulse
groupadd -f pulse-access
groupadd -f audio
usermod -aG audio,pulse,pulse-access user

echo "===== 10 COMPLETE ====="
