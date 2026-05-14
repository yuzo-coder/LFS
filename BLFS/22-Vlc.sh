#!/bin/bash
set -euo pipefail

scripts=(
vlc

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 22    COMPLETE ====="
