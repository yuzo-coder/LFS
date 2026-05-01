#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(

cmake
nasm
yasm
unzip
strace
gdb
lsof
pciutils
hwdata
procps-ng

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 01-COMPLETE ====="
