#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

# 必要なディレクトリの作成
mkdir -p "$SRC" "$LOG"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi


# 4-1. 基礎ライブラリ
# build_meson libepoxy "https://github.com/anholt/libepoxy/archive/1.5.10.tar.gz" "-Dx11=false -Degl=yes"

# build_meson at-spi2-core "https://download.gnome.org/sources/at-spi2-core/2.50/at-spi2-core-2.50.0.tar.xz" ""

# --- 5. 画像処理スタック ---

# GTK3 (Waylandのみ、内省/デモ無効)
#build_meson gtk3 "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.41.tar.xz" \
#     "--wrap-mode=nofallback -Dwayland_backend=true -Dx11_backend=false -Dintrospection=false -Ddemos=false -Dtests=false -Dexamples=false -Dcolord=no"

# 4-2. C++ ユーティリティ
build_cmake fmt "https://github.com/fmtlib/fmt/archive/11.0.2.tar.gz" "-DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF"

build_cmake spdlog "https://github.com/gabime/spdlog/archive/v1.14.1.tar.gz" \
    "-DSPDLOG_FMT_EXTERNAL=ON -DBUILD_SHARED_LIBS=ON -DSPDLOG_BUILD_EXAMPLE=OFF"

build_meson jsoncpp "https://github.com/open-source-parsers/jsoncpp/archive/1.9.5.tar.gz" "-Dtests=false"

#echo "===== Building glibmm (Tutorial script bypass) ====="
#DIR=$(download_extract "https://download.gnome.org/sources/glibmm/2.84/glibmm-2.84.0.tar.xz")
#cd "$DIR"

# mkdir -p subprojects/libsigcplusplus/tools/
# エラーの原因となっているスクリプトを「何もしない」内容で上書き
# cat > subprojects/libsigcplusplus/tools/tutorial-custom-cmd.py << "EOF"
#!/usr/bin/env python3
# import sys
# 何もせずに正常終了(exit 0)を返す
# sys.exit(0)
# EOF

# 実行権限を付与
# chmod +x subprojects/libsigcplusplus/tools/tutorial-custom-cmd.py

# ビルドの再試行
# rm -rf build
# mkdir build && cd build

# meson setup .. \
#     --prefix=/usr \
#    --libdir=/usr/lib \
#     --buildtype=release \
#    -Dbuild-documentation=false \
#    > "$LOG/glibmm.log" 2>&1

# ninja -j"$JOBS" >> "$LOG/glibmm.log" 2>&1
# ninja install >> "$LOG/glibmm.log" 2>&1
# cd "$ROOT_DIR"

# build_mm_lib glibmm "https://download.gnome.org/sources/glibmm/2.84/glibmm-2.84.0.tar.xz" "-Dbuild-documentation=false"

# build_mm_lib mm-common "https://download.gnome.org/sources/mm-common/1.0/mm-common-1.0.6.tar.xz" ""

# echo "===== Building mm-common ====="
# DIR=$(download_extract "https://download.gnome.org/sources/mm-common/1.0/mm-common-1.0.6.tar.xz")
# cd "$DIR"

# rm -rf build && mkdir build && cd build
# meson setup .. --prefix=/usr --buildtype=release > "$LOG/mm-common.log" 2>&1
# ninja install >> "$LOG/mm-common.log" 2>&1
# cd "$ROOT_DIR"

# 4-1. libxslt
echo "===== Building libxslt ====="
# build_autotools libxslt "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz" "--disable-static"

# build_mm_lib pangomm "https://download.gnome.org/sources/pangomm/2.46/pangomm-2.46.4.tar.xz" ""

# build_mm_lib atkmm "https://download.gnome.org/sources/atkmm/2.28/atkmm-2.28.4.tar.xz" ""

# build_meson "libepoxy" "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" "-Dx11=true -Dglx=yes"

# build_mm_lib gtkmm3 "https://download.gnome.org/sources/gtkmm/3.24/gtkmm-3.24.9.tar.xz" "-Dbuild-demos=false -Dbuild-tests=false"

# 4-4. その他依存 (iniparser, date)
build_cmake iniparser "https://github.com/ndevilla/iniparser/archive/v4.2.4.tar.gz" "-DBUILD_SHARED_LIBS=ON"

echo "===== Building HowardHinnant date ====="
DATE_DIR=$(download_extract "https://github.com/HowardHinnant/date/archive/v3.0.1.tar.gz")
cd "$DATE_DIR"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DBUILD_TZ_LIB=ON -DUSE_SYSTEM_TZ_DB=ON ..
make -j"$JOBS" && make install

# pkg-configファイルの手動作成
cat > /usr/lib/pkgconfig/date.pc << "EOF"
prefix=/usr
libdir=${prefix}/lib
includedir=${prefix}/include
Name: date
Description: date and time library
Version: 3.0.1
Libs: -L${libdir} -ldate-tz
Cflags: -I${includedir}
EOF
cd "$ROOT_DIR"

# 4-5. Waybar (Final)
echo "===== Building Waybar ====="
WAYBAR_DIR=$(download_extract "https://github.com/Alexays/Waybar/archive/0.11.0.tar.gz")
cd "$WAYBAR_DIR"

# C++20標準を強制
export CXXFLAGS="-std=c++20"

meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dlibnl=enabled \
    -Dcpp_std=c++20 \
    -Dtests=disabled \
    -Dman-pages=disabled \
    -Dcava=disabled \
    -Dlibnl=disabled \
    -Dlibudev=enabled > "$LOG/waybar.log" 2>&1

ninja -C build -j"$JOBS" >> "$LOG/waybar.log" 2>&1
ninja -C build install >> "$LOG/waybar.log" 2>&1

# 4-2. xmlto (一時的なダミー作成)
# [FIX] /usr/bin 直接ではなく、一時ディレクトリを作成して PATH の先頭に置くのが安全
mkdir -p "$SRC/bin"
cat > "$SRC/bin/xmlto" << "EOF"
#!/bin/sh
exit 0
EOF
chmod +x "$SRC/bin/xmlto"
export PATH="$SRC/bin:$PATH"

# --- 6. swaybg (Final) ---
build_meson "swaybg" "https://github.com/swaywm/swaybg.git" ""

# 後処理
git config --global http.sslVerify true
rm -f "$SRC/bin/xmlto" # [FIX] ダミーの削除

echo "===== ALL COMPLETE: Waybar installed ====="
