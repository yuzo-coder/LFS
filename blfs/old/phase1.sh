#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/sources
LOG=$ROOT/logs

mkdir -p "$SRC" "$LOG"
cd "$SRC"

download_extract() {
    URL=$1
    wget -c "$URL" --no-check-certificate
    TAR=${URL##*/}
    DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$DIR"
}

build_autotools() {
    NAME=$1
    URL=$2
    CONF_OPTS=$3

    echo "===== Building $NAME (autotools) ====="

    DIR=$(download_extract "$URL")
    cd "$DIR"

    ./configure --prefix="$PREFIX" $CONF_OPTS \
        > "$LOG/$NAME.log" 2>&1

    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1

    cd ..
    rm -rf "$DIR"
}

build_meson_bool() {
    NAME=$1
    URL=$2
    EXTRA=$3

    echo "===== Building $NAME (meson-bool) ====="

    DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build

    meson setup build \
        --prefix="$PREFIX" \
        --buildtype=release \
        -Dtests=false \
        $EXTRA \
        > "$LOG/$NAME.log" 2>&1

    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1

    cd ..
    rm -rf "$DIR"
}

build_meson_feature() {
    NAME=$1
    URL=$2
    EXTRA=$3

    echo "===== Building $NAME (meson-feature) ====="

    DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build

    meson setup build \
        --prefix="$PREFIX" \
        --buildtype=release \
        --auto-features=disabled \
        -Dtests=disabled \
        $EXTRA \
        > "$LOG/$NAME.log" 2>&1

    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1

    cd ..
    rm -rf "$DIR"
}

# =============================
# Phase1 Core Libraries
# =============================

build_autotools expat \
https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz \
""

build_autotools libffi \
https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz \
""

build_autotools pcre2 \
https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz \
"--enable-unicode"

# =============================
# GLib2 (boolean型Meson)
# =============================

build_meson_bool glib2 \
https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz \
""

# =============================
# D-Bus
# =============================

build_autotools dbus \
https://dbus.freedesktop.org/releases/dbus/dbus-1.14.10.tar.xz \
"--sysconfdir=/etc \
 --localstatedir=/var \
 --disable-static \
 --enable-systemd"

if command -v systemctl >/dev/null 2>&1; then
    systemctl enable dbus || true
fi

# =============================
# Input stack
# =============================

build_autotools libevdev \
https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz \
"--disable-static"

build_autotools mtdev \
https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz \
"--disable-static"

build_meson_feature libgudev \
https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz \
""

build_meson_feature libwacom \
https://github.com/linuxwacom/libwacom/releases/download/libwacom-2.18.0/libwacom-2.18.0.tar.xz \
""

build_meson_bool libinput \
https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz \
"-Ddebug-gui=false"

echo "===== PHASE1 COMPLETE ====="
