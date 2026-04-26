#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "lsof"
    "unzip"
    "pgrep"
    "pciutils"
    "gdb"
    "strace"

)

for pkg in "${scripts[@]}"; do
    echo "========== Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== PCIUTILS installation completed! ====="
