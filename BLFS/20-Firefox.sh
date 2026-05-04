#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(

python311
firefox128

#firefoxbin

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 20 COMPLETE ====="
