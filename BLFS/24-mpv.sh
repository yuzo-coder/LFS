#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "lcms2"
    "glad2"
    "libplacebo"
    "libass"
    "luajit"
    "mpv"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "mpv --vo=gpu /pathtovideo "

echo "===== COMPLETE ====="
