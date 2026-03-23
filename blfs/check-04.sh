#!/bin/bash
# =================================================================
# LFS Waybar & C++ Stack Verification
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}===== Starting Waybar & C++ Stack Verification =====${NC}"

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "[  ${GREEN}OK${NC}  ] $1"
    else
        echo -e "[ ${RED}FAIL${NC} ] $1"
        return 1
    fi
}

# 1. MMシリーズ (C++ Wrappers) のリンク確認
echo -e "\n--- 1. C++ Library Links (MM-Series) ---"
cpp_libs=("libsigc-2.0.so" "libcairomm-1.0.so" "libglibmm-2.4.so" "libgtkmm-3.0.so" "libpangomm-1.4.so")
for lib in "${cpp_libs[@]}"; do
    ldconfig -p | grep -q "$lib"
    check_status "Library found: $lib"
done

# 2. ユーティリティライブラリの確認
echo -e "\n--- 2. Utility Libraries (fmt, spdlog, jsoncpp) ---"
util_libs=("libfmt.so" "libspdlog.so" "libjsoncpp.so")
for lib in "${util_libs[@]}"; do
    ldconfig -p | grep -q "$lib"
    check_status "Library found: $lib"
done

# 3. pkg-config ファイルの健全性
echo -e "\n--- 3. Pkg-config Files ---"
pkg_configs=("date" "gtkmm-3.0")
for pc in "${pkg_configs[@]}"; do
    pkg-config --exists "$pc"
    check_status "pkg-config: $pc exists"
done

# 4. Waybar バイナリの動的リンク確認 (最重要)
echo -e "\n--- 4. Waybar Binary Integrity ---"
if command -v waybar >/dev/null; then
    # リンク切れ（not found）がないか確認
    ldd $(which waybar) | grep -q "not found"
    if [ $? -ne 0 ]; then
        check_status "Waybar dynamic linking is healthy"
    else
        echo -e "[ ${RED}FAIL${NC} ] Waybar has missing dependencies!"
        ldd $(which waybar) | grep "not found"
    fi
else
    echo -e "[ ${RED}FAIL${NC} ] Waybar binary NOT found in PATH"
fi

# 5. GTK3 Wayland バックエンドの確認
echo -e "\n--- 5. GTK3 Wayland Backend ---"
# GTK3がWaylandサポート付きでビルドされているか
nm -D /usr/lib/libgtk-3.so | grep -q "gdk_wayland_display_get_type"
check_status "GTK3 Wayland backend detected"

echo -e "\n${YELLOW}===== Verification Complete =====${NC}"
echo "To test Waybar within Sway, run: waybar"
echo "Config files should be in: ~/.config/waybar/"
