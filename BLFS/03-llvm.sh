#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libdrm"
    "llvm"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
