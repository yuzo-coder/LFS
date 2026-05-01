#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
shadow
pam
popt
keyutils
systemd
shared-mime-info

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 05-COMPLETE ====="
