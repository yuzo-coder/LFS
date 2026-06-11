#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   15   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

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

su - $TARGET_USER -c "LANG=C LC_ALL=C xdg-user-dirs-update --force"

# systemctl --global enable xdg-desktop-portal xdg-desktop-portal-wlr


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   15   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
