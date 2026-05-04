#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
anthy
extra-cmake-modules
xcb-imdkit
fcitx5
fcitx5-gtk
fcitx5-anthy

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 19 COMPLETE ====="
