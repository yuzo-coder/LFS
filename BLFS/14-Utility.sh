#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libusb
libarchive
libcdio
libcdio-paranoia
libsoup
gvfs
libfm-1
menu-cache
libfm-2
pcmanfm

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
