#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
shadow
pam
dbus

popt
keyutils
systemd
seatd
shared-mime-info

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 05-COMPLETE ====="
