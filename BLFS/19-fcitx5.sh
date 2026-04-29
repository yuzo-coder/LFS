#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "xcb-util-keysyms"
    "libxcb"
    "xcb-util"
    "xcb-util-wm"
    "xcb-imdkit"
    "19-libxkbcommon"
    "fcitx5"
    "fcitx5-gtk"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== /etc/xdg/fcitx5/profile ====="

mkdir -p /etc/xdg/fcitx5

rm -rf /etc/xdg/fcitx5/profile

cat << 'EOF' > /etc/xdg/fcitx5/profile

[Groups/0]
Name=Default
Default Layout=jp
# keyboard-jp を先頭（または anthy の前）に置く
DefaultIMList=keyboard-jp,anthy

[Groups/0/Items/0]
Name=keyboard-jp
Layout=

[Groups/0/Items/1]
Name=anthy
Layout=

[GroupOrder]
0=Default
EOF

echo "===== 15 FCITX Build Completed  ====="

