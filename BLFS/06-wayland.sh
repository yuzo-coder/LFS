#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libxml2"
    "hwdata"
    "doxygen"
    "json-c"
    "wayland"
    "wayland-protocols"
    "wayland-utils"
)

for pkg in "${scripts[@]}"; do
    echo "--- Building $pkg ---"
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 06 WAYLAND COMPLETE:  ====="
