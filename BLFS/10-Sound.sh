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
# pulseaudio
pavucontrol
rtkit
libcanberra

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service

systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service

echo "===== 10 COMPLETE ====="
