#!/bin/bash
set -euo pipefail

source ./functions.sh


DIR=$(download_extract "https://github.com/fcitx/fcitx5-anthy/archive/refs/tags/5.1.0.tar.gz")

cd "$SRC/fcitx5-anthy-5.1.0"

mkdir -p build && cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=/usr/lib \
      -DCMAKE_BUILD_TYPE=Release \
      .. > "$LOG/fcitx5-anthy.log" 2>&1

make >> "$LOG/fcitx5-anthy.log" 2>&1

make install >> "$LOG/fcitx5-anthy.log" 2>&1

ldconfig



echo "===== COMPLETE ====="
