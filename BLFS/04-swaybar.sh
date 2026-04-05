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

# --- 2. 共通ユーティリティ関数 ---

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local CONF_OPTS=$3
    echo "===== Building $NAME (autotools) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    ./configure --prefix="$PREFIX" --libdir=/usr/lib $CONF_OPTS > "$LOG/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# [FIX] GitとURL両方に対応できるよう拡張
build_meson() {
    local NAME=$1; local SRC_URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    
    local DIR=""
    if [[ "$SRC_URL" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone "$SRC_URL" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$SRC_URL")
    fi

    cd "$DIR"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_cmake() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (cmake) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build && mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib $EXTRA .. > "$LOG/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# --- 3. 特殊ビルド関数 (C++ MM-Series用) ---

build_mm_lib() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (MM-Special) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    
    # ドキュメント生成エラーを回避するためのダミーパス作成
    mkdir -p build/subprojects/mm-common
    touch build/subprojects/mm-common/libstdc++.tag
    
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release \
        -Dbuild-documentation=false $EXTRA > "$LOG/$NAME.log" 2>&1
    
    # libsigc++関連のパスも保険で作成
    mkdir -p build/subprojects/libsigcplusplus-2.0/docs/manual/html
    
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# --- 4. ビルド実行プロセス ---

# 4-1. 基礎ライブラリ
build_meson libepoxy "https://github.com/anholt/libepoxy/archive/1.5.10.tar.gz" "-Dx11=false -Degl=yes"
build_meson at-spi2-core "https://download.gnome.org/sources/at-spi2-core/2.50/at-spi2-core-2.50.0.tar.xz" ""

build_meson shared-mime-info "https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.4/shared-mime-info-2.4.tar.gz" ""
# インストール後、MIMEデータベースを更新します
update-mime-database /usr/share/mime

# --- 5. 画像処理スタック ---

# 5-1. libjpeg-turbo
echo "===== Building libjpeg-turbo ====="
DIR=$(download_extract "https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz")
cd "$DIR"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=RELEASE \
      -DENABLE_STATIC=FALSE \
      -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .. > "$LOG/libjpeg-turbo.log" 2>&1
make -j"$JOBS" >> "$LOG/libjpeg-turbo.log" 2>&1
make install >> "$LOG/libjpeg-turbo.log" 2>&1
ldconfig # [FIX] 追加
cd "$ROOT_DIR"

# 5-2. gdk-pixbuf
# [FIX] build_meson関数を使用し、jpegを明示的に有効化
build_meson "gdk-pixbuf" "https://gitlab.gnome.org/GNOME/gdk-pixbuf.git" \
    "-Dglycin=disabled -Dbuiltin_loaders=all -Djpeg=enabled -Dothers=enabled -Dman=false -Dintrospection=disabled -Dtests=false"


# GTK3 (Waylandのみ、内省/デモ無効)
build_meson gtk3 "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.41.tar.xz" \
    "--wrap-mode=nofallback -Dwayland_backend=true -Dx11_backend=false -Dintrospection=false -Ddemos=false -Dtests=false -Dexamples=false -Dcolord=no"

# 4-2. C++ ユーティリティ
build_cmake fmt "https://github.com/fmtlib/fmt/archive/11.0.2.tar.gz" "-DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF"

build_cmake spdlog "https://github.com/gabime/spdlog/archive/v1.14.1.tar.gz" \
    "-DSPDLOG_FMT_EXTERNAL=ON -DBUILD_SHARED_LIBS=ON -DSPDLOG_BUILD_EXAMPLE=OFF"

build_meson jsoncpp "https://github.com/open-source-parsers/jsoncpp/archive/1.9.5.tar.gz" "-Dtests=false"

# 4-3. MMシリーズ (C++ Wrappers)
build_mm_lib libsigc++ "https://download.gnome.org/sources/libsigc++/2.12/libsigc++-2.12.0.tar.xz" ""
build_mm_lib cairomm "https://www.cairographics.org/releases/cairomm-1.14.5.tar.xz" ""
build_mm_lib libsigc++3 "https://download.gnome.org/sources/libsigc++/3.6/libsigc++-3.6.0.tar.xz" ""
echo "===== Building glibmm (Tutorial script bypass) ====="
DIR=$(download_extract "https://download.gnome.org/sources/glibmm/2.84/glibmm-2.84.0.tar.xz")
cd "$DIR"

mkdir -p subprojects/libsigcplusplus/tools/
# エラーの原因となっているスクリプトを「何もしない」内容で上書き
cat > subprojects/libsigcplusplus/tools/tutorial-custom-cmd.py << "EOF"
#!/usr/bin/env python3
import sys
# 何もせずに正常終了(exit 0)を返す
sys.exit(0)
EOF

# 実行権限を付与
chmod +x subprojects/libsigcplusplus/tools/tutorial-custom-cmd.py

# ビルドの再試行
rm -rf build
mkdir build && cd build

meson setup .. \
    --prefix=/usr \
    --libdir=/usr/lib \
    --buildtype=release \
    -Dbuild-documentation=false \
    > "$LOG/glibmm.log" 2>&1

ninja -j"$JOBS" >> "$LOG/glibmm.log" 2>&1
ninja install >> "$LOG/glibmm.log" 2>&1
cd "$ROOT_DIR"

# build_mm_lib glibmm "https://download.gnome.org/sources/glibmm/2.84/glibmm-2.84.0.tar.xz" "-Dbuild-documentation=false"

# build_mm_lib mm-common "https://download.gnome.org/sources/mm-common/1.0/mm-common-1.0.6.tar.xz" ""
echo "===== Building mm-common ====="
DIR=$(download_extract "https://download.gnome.org/sources/mm-common/1.0/mm-common-1.0.6.tar.xz")
cd "$DIR"

rm -rf build && mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release > "$LOG/mm-common.log" 2>&1
ninja install >> "$LOG/mm-common.log" 2>&1
cd "$ROOT_DIR"

# 4-1. libxslt
echo "===== Building libxslt ====="
build_autotools libxslt "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz" "--disable-static"

build_mm_lib pangomm "https://download.gnome.org/sources/pangomm/2.46/pangomm-2.46.4.tar.xz" ""
build_mm_lib atkmm "https://download.gnome.org/sources/atkmm/2.28/atkmm-2.28.4.tar.xz" ""
build_mm_lib gtkmm "https://download.gnome.org/sources/gtkmm/3.24/gtkmm-3.24.9.tar.xz" ""

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
