#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libevdev
mtdev
libinput
libdisplay-info
# libgudev
# seatd

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
