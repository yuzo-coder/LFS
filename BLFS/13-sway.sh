#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libevdev"
    "libinput"
    "wlroots"
    "xcb-util-renderutil"
    "libxcvt"
    "xwayland"
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
