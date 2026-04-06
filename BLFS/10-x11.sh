#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
XORG_CONFIG="--prefix=$PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
ROOT_DIR=${ROOT_DIR:-$(pwd)}
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
BASE_URL_LIB="https://www.x.org/archive/individual/lib"
BASE_URL_PROTO="https://www.x.org/archive/individual/proto"
BASE_URL_XCB="https://xcb.freedesktop.org/dist"

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# --- 3. 依存関係のビルド (下位レイヤーから順に) ---

# 1. xorgproto (ヘッダファイル)
build_autotools "xorgproto" "$BASE_URL_PROTO/xorgproto-2024.1.tar.xz" ""

# 第2層: libxcb のための必須低層ライブラリ (Xau, Xdmcp)
build_autotools "libXau"   "$BASE_URL_LIB/libXau-1.0.11.tar.xz" ""
build_autotools "libXdmcp" "$BASE_URL_LIB/libXdmcp-1.1.5.tar.xz" ""

# 2. xcb-proto (XMLベースのプロトコル定義 - libxcbに必須)
build_autotools "xcb-proto" "https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz" ""

# 3. libpthread-stubs (プラットフォームによっては必須)
build_autotools "libpthread-stubs" "https://xcb.freedesktop.org/dist/libpthread-stubs-0.4.tar.bz2" ""

# 4. libxcb (これが足りないと怒られていた本体)
build_autotools "libxcb" "https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz" ""

# --- 4. X7 Libraries 実行セクション ---

cat > lib-7.list << "EOF"
xtrans-1.6.0.tar.xz
libX11-1.8.12.tar.xz
libXext-1.3.6.tar.xz
libFS-1.0.10.tar.xz
libICE-1.1.2.tar.xz
libSM-1.2.6.tar.xz
libXScrnSaver-1.2.4.tar.xz
libXt-1.3.1.tar.xz
libXmu-1.2.1.tar.xz
libXpm-3.5.17.tar.xz
libXaw-1.0.16.tar.xz
libXfixes-6.0.1.tar.xz
libXcomposite-0.4.6.tar.xz
libXrender-0.9.12.tar.xz
libXcursor-1.2.3.tar.xz
libXdamage-1.1.6.tar.xz
libfontenc-1.1.8.tar.xz
libXfont2-2.0.7.tar.xz
libXft-2.3.9.tar.xz
libXi-1.8.2.tar.xz
libXinerama-1.1.5.tar.xz
libXrandr-1.5.4.tar.xz
libXres-1.2.2.tar.xz
libXtst-1.2.5.tar.xz
libXv-1.0.13.tar.xz
libXvMC-1.0.14.tar.xz
libXxf86dga-1.1.6.tar.xz
libXxf86vm-1.1.6.tar.xz
libpciaccess-0.18.1.tar.xz
libxkbfile-1.1.3.tar.xz
libxshmfence-1.3.3.tar.xz
libXpresent-1.0.1.tar.xz
EOF

# --- 修正版：ビルド実行ループ ---

while read -r TARBALL; do
    [ -z "$TARBALL" ] && continue
    NAME=$(echo "$TARBALL" | sed 's/\.tar\.xz//; s/\.tar\.bz2//')
    
    # 既に別枠でビルドした低層ライブラリはスキップ
    if [[ "$NAME" == "libXau"* || "$NAME" == "libXdmcp"* || "$NAME" == "xorgproto"* || "$NAME" == "libxcb"* || "$NAME" == "xcb-proto"* ]]; then 
        continue 
    fi

    echo "===== Checking Build System for: $NAME ====="
    DIR=$(download_extract "$BASE_URL_LIB/$TARBALL")
    cd "$DIR"

    # --- 自動判別ロジック ---
    if [ -f "meson.build" ]; then
        # Mesonビルドの場合
        echo "Detected Meson build system..."
        rm -rf build
        # EXTRAオプションが必要な場合はここで設定
        EXTRA="" 
        meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
        ninja -C build >> "$LOG/$NAME.log" 2>&1
        sudo ninja -C build install >> "$LOG/$NAME.log" 2>&1
    elif [ -f "configure" ] || [ -f "autogen.sh" ]; then
        # Autotoolsビルドの場合
        echo "Detected Autotools build system..."
        # autogen.sh しかない場合は実行
        if [ ! -f "configure" ]; then ./autogen.sh $XORG_CONFIG > "$LOG/$NAME.log" 2>&1; fi
        
        OPTS=""
        case "$NAME" in
            libICE*) OPTS="--enable-docs=no" ;;
            libX11*) OPTS="--enable-specs=no" ;;
            libXpm*) OPTS="--disable-open-zfile" ;;
        esac
        
        ./configure $XORG_CONFIG $OPTS >> "$LOG/$NAME.log" 2>&1
        make >> "$LOG/$NAME.log" 2>&1
        sudo make install >> "$LOG/$NAME.log" 2>&1
    else
        echo "Error: Unknown build system for $NAME" | tee -a "$LOG/errors.log"
    fi

    sudo ldconfig
    cd "$ROOT_DIR"
    echo "Successfully installed $NAME"
done < lib-7.list

echo "Done! Verify with: ls /usr/share/X11/locale/ja_JP.UTF-8/"
