#!/bin/bash
# =================================================================
# LFS Sway & Graphics Stack Verification
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}===== Starting GUI Stack Verification =====${NC}"

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "[  ${GREEN}OK${NC}  ] $1"
    else
        echo -e "[ ${RED}FAIL${NC} ] $1"
        return 1
    fi
}

# 1. ライブラリのリンク確認 (主要なもの)
echo -e "\n--- 1. Shared Library Links ---"
libs=("libwayland-client.so" "libdrm.so" "libgbm.so" "libinput.so" "libxkbcommon.so")
for lib in "${libs[@]}"; do
    ldconfig -p | grep -q "$lib"
    check_status "Library found: $lib"
done

# 2. Mesa / GPU 加速の確認
echo -e "\n--- 2. Graphics Driver (Mesa) ---"
[ -d /usr/lib/dri ] && ls /usr/lib/dri | grep -qE "virtio_gpu|swrast"
check_status "Mesa DRI drivers (virtio/swrast) installed"

# 3. 入力デバイスのパーミッション (libinput)
echo -e "\n--- 3. Input Device Access ---"
if command -v libinput >/dev/null; then
    # 一般ユーザー権限でアクセス可能か（グループ設定の確認）
    id -nG user | grep -E "input|video" >/dev/null
    check_status "User 'user' has input/video group privileges"
else
    echo -e "[ ${YELLOW}SKIP${NC} ] libinput-debug-events not found"
fi

# 4. フォントとレンダリング
echo -e "\n--- 4. Fonts & Rendering ---"
fc-list | grep "mono" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    check_status "At least one Monospace font found"
else
    echo -e "[ ${YELLOW}WARN${NC} ] No fonts found. foot might fail to start."
fi

# 5. Sway & wlroots のバイナリチェック
echo -e "\n--- 5. Sway & wlroots ---"
command -v sway >/dev/null
check_status "Sway binary found"

sway --version | grep -q "version 1.9"
check_status "Sway version 1.9 verified"

# 6. foot ターミナルの確認
echo -e "\n--- 6. Terminal (foot) ---"
command -v foot >/dev/null
check_status "foot binary found"

[ -f /home/user/.config/foot/foot.ini ]
check_status "foot config file exists"

echo -e "\n${YELLOW}===== Verification Complete =====${NC}"
echo "To start Sway, login as 'user' and run: sway"
