#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# Python依存の解決
pip3 install --break-system-packages mako pyserpent 2>/dev/null || true

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
    make >> "$LOG/$NAME.log" 2>&1
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
    ninja -C build >> "$LOG/$NAME.log" 2>&1
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
    make >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# --- 3. 基礎ライブラリ (Base) ---
build_autotools expat "https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz" ""
build_autotools libffi "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz" ""
build_autotools pcre2 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz" "--enable-unicode"
build_meson glib2 "https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz" "-Dtests=false"

# --- 4. ツールチェーン (CMake Bootstrap) ---
if ! command -v cmake &> /dev/null; then
    echo "===== Building CMake (Bootstrap) ====="
    DIR=$(download_extract "https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz")
    cd "$DIR"
    ./bootstrap --prefix="$PREFIX" --parallel="$JOBS" --no-system-curl --no-system-libs > "$LOG/cmake-bootstrap.log" 2>&1
    make >> "$LOG/cmake-bootstrap.log" 2>&1
    make install >> "$LOG/cmake-bootstrap.log" 2>&1
    cd "$ROOT_DIR"
fi

# --- 5. PAM & Shadow ログインスタック ---
# PAM導入
build_meson linux-pam "https://github.com/linux-pam/linux-pam/releases/download/v1.7.2/Linux-PAM-1.7.2.tar.xz" "-Ddocs=disabled -Dnis=disabled"

# PAM設定の最小構成（これがないとログインできなくなります）
if [ ! -f /etc/pam.d/other ]; then
    mkdir -p /etc/pam.d
    cat > /etc/pam.d/other << "EOF"
auth     required       pam_unix.so
account  required       pam_unix.so
password required       pam_unix.so
session  required       pam_unix.so
EOF
fi

# Shadow再ビルド (PAM有効化)
build_autotools shadow "https://github.com/shadow-maint/shadow/releases/download/4.18.0/shadow-4.18.0.tar.xz" \
    "--sysconfdir=/etc --disable-static --with-libpam --without-libbsd"

# Systemd (PAM有効化)
build_meson systemd "https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz" "-Dpam=enabled -Dmode=release"

# --- 6. Wayland & Graphics Foundation ---
build_autotools libxml2 "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz" "--disable-static --without-python"
build_autotools hwdata "https://github.com/vcrhonek/hwdata/archive/v0.404/hwdata-0.404.tar.gz" ""

build_cmake doxygen "https://doxygen.nl/files/doxygen-1.16.1.src.tar.gz" "-DCMAKE_BUILD_TYPE=Release"
build_cmake json-c "https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

build_meson wayland "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz" "-Ddocumentation=false"
build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.36/downloads/wayland-protocols-1.36.tar.xz" ""
build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""
build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland -Dglx=disabled -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers= -Dllvm=disabled"

# --- 7. Input Stack ---
build_autotools libevdev "https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz" "--disable-static"
build_autotools mtdev "https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz" "--disable-static"
build_meson libgudev "https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz" ""
build_meson libinput "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz" "-Ddebug-gui=false -Dtests=false -Ddocumentation=false"

# --- 8. Font & Drawing Stack (Pango Chain) ---
build_meson pixman "https://www.cairographics.org/releases/pixman-0.43.4.tar.gz" ""
build_autotools libpng "https://downloads.sourceforge.net/libpng/libpng-1.6.55.tar.xz" ""
build_autotools freetype "https://downloads.sourceforge.net/freetype/freetype-2.13.2.tar.xz" "--disable-static"
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" "--sysconfdir=/etc --localstatedir=/var --disable-docs"

build_meson fribidi "https://github.com/fribidi/fribidi/releases/download/v1.0.15/fribidi-1.0.15.tar.xz" ""
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/9.0.0/harfbuzz-9.0.0.tar.xz" ""
build_meson cairo "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz" \
    "-Dfontconfig=enabled -Dfreetype=enabled -Dxcb=disabled -Dxlib=disabled -Dtests=disabled"
build_meson pango "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz" "-Dintrospection=disabled"

# --- 9. Sway & Wlroots ---
build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" ""
build_meson libxkbcommon "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" "-Denable-x11=false"
build_meson xkeyboard-config "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz" ""

build_meson wlroots "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.2/wlroots-0.17.2.tar.gz" \
    "-Dbackends=drm,libinput -Dxwayland=disabled"

build_meson sway "https://github.com/swaywm/sway/releases/download/1.9/sway-1.9.tar.gz" "-Dxwayland=disabled"

echo "===== ALL PHASES COMPLETE: Sway is ready ====="
