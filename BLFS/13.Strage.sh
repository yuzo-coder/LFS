#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libatasmart
libaio
lvm2
cryptsetup
libblockdev
udisks2

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 13 COMPLETE ====="
