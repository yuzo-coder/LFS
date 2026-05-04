#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(

xwayland
wlroots
sway
swaybg
Waybar
wofi
wlogout
wl-clipboard
foot

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 17 COMPLETE ====="
