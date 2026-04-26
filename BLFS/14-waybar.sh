#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "fmt"
    "spdlog"
    "jsoncpp"
    "iniparser"
    "HowardHinnant"
    "Waybar"
    "swaybg"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


# 後処理
#git config --global http.sslVerify true
#rm -f "$SRC/bin/xmlto" # [FIX] ダミーの削除

echo "===== ALL COMPLETE: Waybar installed ====="
