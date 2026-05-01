#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
xdg-user-dirs
xdg-dbus-proxy
bubblewrap
fuse3

#json-glib
libpcap
umockdev
desktop-file-utils
inih
xdg-desktop-portal
xdg-desktop-portal-wlr

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
