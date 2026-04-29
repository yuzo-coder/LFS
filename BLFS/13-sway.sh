#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libevdev"
    "mtdev"
    "libinput"
    "libtirpc"
    "libxcvt"
    "xwayland"
    "xkbcomp"
    "font-util"
    "xcb-util-renderutil"
    "xcb-util"
    "xcb-util-image"
    "xcb-util-wm"
    "xcb-util-keysyms"
    "xorg-server"
    "wlroots"
    "xcb-util-renderutil"
    "libxcvt"
    "sway"
    "tllist"
    "fcft"
    "foot"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""

# --- 8. 完了処理 ---
echo "---"
echo "===== ALL PHASES COMPLETE: Sway & foot are ready ====="
echo "Usage: Start Sway and use 'foot' as your terminal emulator."
