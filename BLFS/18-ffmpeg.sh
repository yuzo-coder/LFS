#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "nasm"
    "x264"
    "libva"
    "fdk-aac"
    "libvpx"
    "ffmpeg"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "=================================================="
echo "FFMPEG Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
