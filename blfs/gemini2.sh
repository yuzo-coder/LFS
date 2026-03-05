#!/bin/bash
set -euo pipefail

# 1. 環境・絶対パス設定
JOBS=$(nproc)
ROOT_DIR=$(pwd)
SOURCE_DIR="$ROOT_DIR/sources"
LOG_DIR="$ROOT_DIR/logs"

mkdir -p "$SOURCE_DIR" "$LOG_DIR"

export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# 2. ユーティリティ関数
download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    
    cd "$SOURCE_DIR"
    wget -c "$URL" --no-check-certificate >&2 || true
    
    local DIR_NAME=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR_NAME"
    tar xf "$TAR"
    
    echo "$SOURCE_DIR/$DIR_NAME"
}

build_meson() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    local TARGET_DIR=$(download_extract "$URL")
    
    cd "$TARGET_DIR"
    rm -rf build
    # --libdir=/usr/lib を明示して LFS の 64bit ライブラリパス問題を回避
    meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG_DIR/$NAME.log" 2>&1 || { echo "Meson Failed. See $LOG_DIR/$NAME.log"; exit 1; }
    ninja -C build -j"$JOBS" >> "$LOG_DIR/$NAME.log" 2>&1
    ninja -C build install >> "$LOG_DIR/$NAME.log" 2>&1
    ldconfig
    
    cd "$ROOT_DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (autotools) ====="
    local TARGET_DIR=$(download_extract "$URL")
    
    cd "$TARGET_DIR"
    ./configure --prefix=/usr --libdir=/usr/lib $EXTRA > "$LOG_DIR/$NAME.log" 2>&1 || { echo "Configure Failed. See $LOG_DIR/$NAME.log"; exit 1; }
    make -j"$JOBS" >> "$LOG_DIR/$NAME.log" 2>&1
    make install >> "$LOG_DIR/$NAME.log" 2>&1
    ldconfig
    
    cd "$ROOT_DIR"
}

# ==========================================
# 4. ビルド実行
# ==========================================

# Linux-PAM (Mesonビルドに変更)
# -Dnis=disabled: LFSでは通常不要
# -Ddoc=disabled: ドキュメント生成エラーを回避
build_meson linux-pam "https://github.com/linux-pam/linux-pam/releases/download/v1.7.2/Linux-PAM-1.7.2.tar.xz" "-Ddocs=disabled"

# systemd (PAM有効化)
build_meson systemd "https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz" "-Dpam=enabled -Dmode=release"

# --- 以下、前回のグラフィックスタックを継続 ---
build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""
build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland -Dglx=disabled -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers= -Dllvm=disabled"

build_meson pixman "https://www.cairographics.org/releases/pixman-0.43.4.tar.gz" ""

# libpng (FreeType のカラーフォントサポートに必須)
build_autotools libpng "https://downloads.sourceforge.net/libpng/libpng-1.6.55.tar.xz" ""

build_autotools freetype "https://downloads.sourceforge.net/freetype/freetype-2.13.2.tar.xz" "--disable-static"
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" "--sysconfdir=/etc --localstatedir=/var --disable-docs"

# --- 描画スタックのビルド順序を修正 ---

# 1. FriBidi (Pangoの必須依存)
build_meson fribidi "https://github.com/fribidi/fribidi/releases/download/v1.0.15/fribidi-1.0.15.tar.xz" ""

# 1. libdatrie (libthai の必須依存)
build_autotools libdatrie "https://linux.thai.net/pub/thailinux/software/libthai/libdatrie-0.2.13.tar.xz" "--disable-static"

# 2. libthai (推奨)
build_autotools libthai "https://linux.thai.net/pub/thailinux/software/libthai/libthai-0.1.29.tar.xz" "--disable-static --disable-dict"

# 3. Cairo (Pango の描画エンジンとして必須)
# X11関連(xcb/xlib)を無効にし、Wayland環境向けに構成します
build_meson cairo "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz" \
    "-Dfontconfig=enabled -Dfreetype=enabled -Dtee=enabled -Dxcb=disabled -Dxlib=disabled -Dtests=disabled"

# 3. HarfBuzz (Pangoの前に必要)
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/9.0.0/harfbuzz-9.0.0.tar.xz" ""


# 4. Pango (ここで FriBidi が /usr/lib に存在すればエラーは消えます)
build_meson pango "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz" "-Dintrospection=disabled"

build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" ""
build_meson libxkbcommon "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" "-Denable-x11=false"
build_meson xkeyboard-config "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz" ""

build_meson wlroots "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.2/wlroots-0.17.2.tar.gz" \
    "-Dbackends=drm,libinput -Dxwayland=disabled"

build_meson sway "https://github.com/swaywm/sway/releases/download/1.9/sway-1.9.tar.gz" "-Dxwayland=disabled"

echo "===== PHASE2 COMPLETE ====="

