#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "xorgproto"
    "libXau"
    "libXdmcp"
    "xcb-proto"
    "libpthread-stubs"
    "libxcb"
    "xdg-user-dirs"
    "xdg-dbus-proxy"
    "lib-7"
    "Vulkan-Headers"
    "Vulkan-Loader"
)

for pkg in "${scripts[@]}"; do
    echo "--- Building $pkg ---"
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 05 COMPLETE ====="
echo "Done! Verify with: ls /usr/share/X11/locale/ja_JP.UTF-8/"
