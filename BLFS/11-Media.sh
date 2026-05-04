#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libaom
libavif
libvdpau
libva
x264
libvpx
fdk-aac
ffmpeg
libass
glad2
lcms2
libplacebo
mpv
desktop-file-utils
celluloid

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 11 COMPLETE ====="
