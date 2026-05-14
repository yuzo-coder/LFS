#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
xdg-user-dirs
xdg-dbus-proxy
bubblewrap
fuse3

libpcap
umockdev
inih
xdg-desktop-portal
xdg-desktop-portal-wlr

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

systemctl --user enable xdg-desktop-portal xdg-desktop-portal-wlr

systemctl --user start xdg-desktop-portal xdg-desktop-portal-wlr

echo "===== 15 COMPLETE ====="
