#!/bin/bash
set -euo pipefail

# 1. 環境設定
JOBS=$(nproc)
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# ログディレクトリの作成
mkdir -p ../logs
LOG_DIR=$(realpath ../logs)

# 2. 依存ツール（Mesa用）
echo "===== Installing Build Dependencies ====="
pip3 install --break-system-packages mako pyserpent 2>/dev/null || true

# 3. ビルド用共通関数
build_meson() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME ====="
    local TAR=${URL##*/}
    wget -c "$URL" --no-check-certificate
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR" && tar xf "$TAR" && cd "$DIR"
    
    meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG_DIR/$NAME.log" 2>&1
    ninja -C build -j"$JOBS" >> "$LOG_DIR/$NAME.log" 2>&1
    ninja -C build install >> "$LOG_DIR/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME ====="
    local TAR=${URL##*/}
    wget -c "$URL" --no-check-certificate
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR" && tar xf "$TAR" && cd "$DIR"

    ./configure --prefix=/usr --libdir=/usr/lib $EXTRA > "$LOG_DIR/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG_DIR/$NAME.log" 2>&1
    make install >> "$LOG_DIR/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

# --- 順序が重要：基礎から積み上げます ---

# 1. 基礎ライブラリ (XML / GLib / JSON)
build_autotools libxml2 "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz" "--disable-static"
build_meson glib "https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz" "-Dtests=false"

# json-c (CMakeを使用するため個別処理)
echo "===== Building json-c ====="
wget -c "https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz" --no-check-certificate
tar xf json-c-0.18.tar.gz && cd json-c-0.18
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=ON .. > "$LOG_DIR/json-c.log" 2>&1
make -j"$JOBS" >> "$LOG_DIR/json-c.log" 2>&1
make install >> "$LOG_DIR/json-c.log" 2>&1
ldconfig
cd ../.. && rm -rf json-c-0.18

# 2. グラフィック低層 (DRM / Wayland / Mesa)
build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""
build_meson wayland "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.24.0/downloads/wayland-1.24.0.tar.xz" "-Ddocumentation=false"
build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.40/downloads/wayland-protocols-1.40.tar.xz" ""

# Mesa (VirtIO ターゲット)
build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland -Dglx=disabled -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers= -Dllvm=disabled"

# 3. 文字・描画スタック
build_meson pixman "https://www.cairographics.org/releases/pixman-0.43.4.tar.gz" ""
build_autotools freetype "https://downloads.sourceforge.net/freetype/freetype-2.13.2.tar.xz" "--disable-static"
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" "--sysconfdir=/etc --localstatedir=/var --disable-docs"
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/9.0.0/harfbuzz-9.0.0.tar.xz" ""
build_meson pango "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz" ""

# 4. 入力・権限管理 (seatd / xkb)
build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" ""
build_meson libxkbcommon "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" "-Denable-x11=false"
# 【追加】これがないと前回のエラーが再発します
build_meson xkeyboard-config "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.41.tar.xz" ""

# 5. いよいよ Sway 核心部
# wlroots (DRMを強制有効)
build_meson wlroots "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.2/wlroots-0.17.2.tar.gz" \
    "-Dbackends=drm,libinput -Dxwayland=disabled"

# sway (最終目的)
build_meson sway "https://github.com/swaywm/sway/releases/download/1.9/sway-1.9.tar.gz" "-Dxwayland=disabled"

echo "===== PHASE2 COMPLETE: Sway is ready! ====="
echo "Run: 'sway' from a TTY (Make sure seatd is running or you are in 'seat' group)"
