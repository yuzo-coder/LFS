#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libxmlb"
    "libadwaita"
    "desktop-file-utils"
    "celluloid"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done





build_meson "celluloid" \
    "https://github.com/celluloid-player/celluloid/archive/refs/tags/v0.28.tar.gz" \
    ""


echo "===== COMPLETE ====="

