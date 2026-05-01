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

echo "===== LLVM COMPLETE ====="
