#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
font-util
freetype
harfbuzz
fontconfig
fribidi
libpng
libjpeg-turbo
libtiff
libwebp
libyuv
gdk-pixbuf
JetBrainsMono
noto

iso-codes
gstreamer
gst-plugins-base

gst-plugins-good
gst-plugins-bad

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
