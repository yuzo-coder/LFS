#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/sources
LOG=$ROOT/logs

mkdir -p "$SRC" "$LOG"
cd "$SRC"

# --- ユーティリティ関数 ---

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    # echoは標準エラー出力(>&2)に逃がし、戻り値をDIR名のみにする
    echo "Downloading $TAR..." >&2
    wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$DIR"
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
    cd .. && rm -rf "$DIR"
}

build_meson_bool() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson-bool) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release -Dtests=false $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

build_meson_feature() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson-feature) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build
    # feature型(enabled/disabled)を想定
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release  $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

build_cmake() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (cmake) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build && mkdir build && cd build
    # CMake 4.x対策としてポリシー最小値を指定
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POLICY_VERSION_MINIMUM=3.5 $EXTRA .. > "$LOG/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd ../.. && rm -rf "$DIR"
}

# =============================
# 1. 基礎ライブラリ (Base)
# =============================
build_autotools expat "https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz" ""
build_autotools libffi "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz" ""
build_autotools pcre2 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz" "--enable-unicode"
build_meson_bool glib2 "https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz" ""

# =============================
# 2. ツールチェーン (CMake Bootstrap)
# =============================
echo "===== Building CMake (Bootstrap) ====="
# CMake 4.1.0 (内蔵ライブラリ使用)
CMAKE_URL="https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz"
CMAKE_DIR=$(download_extract "$CMAKE_URL")
cd "$CMAKE_DIR"
./bootstrap --prefix="$PREFIX" --parallel="$JOBS" --no-system-curl --no-system-libs > "$LOG/cmake-bootstrap.log" 2>&1
make -j"$JOBS" >> "$LOG/cmake-bootstrap.log" 2>&1
make install >> "$LOG/cmake-bootstrap.log" 2>&1
ldconfig
cd .. && rm -rf "$CMAKE_DIR"

# =============================
# 3. グラフィック基盤依存 (xml/hwdata/json)
# =============================
build_autotools libxml2 "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz" "--disable-static --without-python"
build_autotools hwdata "https://github.com/vcrhonek/hwdata/archive/v0.404/hwdata-0.404.tar.gz" ""
build_cmake json-c "https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz" ""

# =============================
# 4. Wayland 核心部
# =============================
build_meson_bool wayland "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz" "-Ddocumentation=false"
build_meson_bool wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.36/downloads/wayland-protocols-1.36.tar.xz" ""
build_meson_feature libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

# =============================
# 5. D-Bus
# =============================
# D-Bus 1.16.2 のビルド例
# build_meson_feature dbus "https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz" \
#    "-Druntime_dir=/run \
#     -Dsystemd=enabled \
#     -Dsystemd_system_unitdir=/usr/lib/systemd/system \
#     -Dsystemd_user_unitdir=/usr/lib/systemd/user \
#     -Duser_session=true \
#     -Dselinux=disabled \
#     -Dxml_docs=disabled \
#     -Ddoxygen_docs=disabled \
#     -Ddbus_user=dbus"

# =============================
# 6. Input stack
# =============================
build_autotools libevdev "https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz" "--disable-static"
build_autotools mtdev "https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz" "--disable-static"
build_meson_feature libgudev "https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz" ""
build_meson_feature libwacom "https://github.com/linuxwacom/libwacom/releases/download/libwacom-2.18.0/libwacom-2.18.0.tar.xz" "-Dtests=disabled"

# libinput は feature型関数の tests=disabled を利用
build_meson_feature libinput "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz" "-Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dinstall-tests=false"

echo "===== PHASE1 COMPLETE: Ready for Phase 2 (Mesa & Sway) ====="

