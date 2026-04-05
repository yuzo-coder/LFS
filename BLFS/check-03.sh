#!/bin/bash
# =================================================================
# LFS Graphics Stack & swaybg Verification
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}===== Starting Graphics/swaybg Verification =====${NC}"

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "[  ${GREEN}OK${NC}  ] $1"
    else
        echo -e "[ ${RED}FAIL${NC} ] $1"
        return 1
    fi
}

# 1. 共有ライブラリのインストール確認
echo -e "\n--- 1. Shared Libraries ---"
libs=("libjpeg.so" "libturbojpeg.so" "libgdk_pixbuf-2.0.so" "libxslt.so")
for lib in "${libs[@]}"; do
    ldconfig -p | grep -q "$lib"
    check_status "Library found: $lib"
done

# 2. フォントの認識確認
echo -e "\n--- 2. Font Management ---"
fc-list | grep -qi "DejaVu"
check_status "DejaVu Fonts recognized by fontconfig"
fc-list | grep -qi "Noto"
check_status "Noto Fonts recognized by fontconfig"

# 4. MIME データベースの確認
echo -e "\n--- 4. MIME Type Database ---"
[ -f /usr/share/mime/magic ]
check_status "MIME database generated"
update-mime-database -v /usr/share/mime >/dev/null 2>&1
check_status "MIME database is updatable"

# 5. swaybg バイナリの確認
echo -e "\n--- 5. swaybg Binary ---"
command -v swaybg >/dev/null
check_status "swaybg binary found in PATH"

# 共有ライブラリの欠損がないか動的リンクを最終チェック
ldd $(which swaybg) | grep -q "not found"
if [ $? -ne 0 ]; then
    check_status "swaybg dynamic linking is healthy"
else
    echo -e "[ ${RED}FAIL${NC} ] swaybg has missing dependencies!"
    ldd $(which swaybg) | grep "not found"
fi

echo -e "\n${YELLOW}===== Verification Complete =====${NC}"
echo "To test swaybg manually within Sway, run:"
echo "  swaybg -i /path/to/your/wallpaper.jpg -m fill"
