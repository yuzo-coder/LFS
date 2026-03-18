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

build_meson() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    local DIR=$(download_extract "$URL")
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

# GTK3 (Waylandのみ、内省/デモ無効)
build_meson gtk3 "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.41.tar.xz" \
    "-Dwayland_backend=true -Dx11_backend=false -Dintrospection=false -Ddemos=false -Dtests=false -Dexamples=false -Dcolord=no"

# 4-2. C++ ユーティリティ
build_cmake fmt "https://github.com/fmtlib/fmt/archive/11.0.2.tar.gz" "-DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF"
build_cmake spdlog "https://github.com/gabime/spdlog/archive/v1.14.1.tar.gz" "-DSPDLOG_FMT_EXTERNAL=ON -DBUILD_SHARED_LIBS=ON"
build_meson jsoncpp "https://github.com/open-source-parsers/jsoncpp/archive/1.9.5.tar.gz" "-Dtests=false"

# 4-3. MMシリーズ (C++ Wrappers)
build_mm_lib libsigc++ "https://download.gnome.org/sources/libsigc++/2.12/libsigc++-2.12.0.tar.xz" ""
build_mm_lib cairomm "https://www.cairographics.org/releases/cairomm-1.14.5.tar.xz" ""
build_mm_lib pangomm "https://download.gnome.org/sources/pangomm/2.46/pangomm-2.46.4.tar.xz" ""
build_mm_lib atkmm "https://download.gnome.org/sources/atkmm/2.28/atkmm-2.28.4.tar.xz" ""
build_mm_lib gtkmm "https://download.gnome.org/sources/gtkmm/3.24/gtkmm-3.24.9.tar.xz" ""

# 4-4. その他依存 (iniparser, date)
build_cmake iniparser "https://github.com/ndevilla/iniparser/archive/v4.1.tar.gz" "-DBUILD_SHARED_LIBS=ON"

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

echo "===== ALL COMPLETE: Waybar installed ====="
