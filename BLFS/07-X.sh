#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   07   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
xorgproto
libXau
libXdmcp
xcb-proto
libxcb
lib-7

xcb-util
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
libICE
libSM

libxcvt
xkeyboard-config
libxshmfence

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   07   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
