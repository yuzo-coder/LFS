#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libnl
libndp
mobile-broadband-provider-info

duktape
polkit
libgudev
libbytesize
libnvme
libsecret

NetworkManager
libnma
network-manager-applet

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
