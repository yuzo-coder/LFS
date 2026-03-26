#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. ユーティリティ関数 ---
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

# --- 3. Sway初期設定 & フォント配置 ---
echo "===== Configuring Sway & Fonts ====="
# ユーザー設定ディレクトリの準備
mkdir -pv ~/.config/sway
mkdir -pv /home/user/.config/sway
if [ -f /etc/sway/config ]; then
    cp -v /etc/sway/config ~/.config/sway/config
    cp -v /etc/sway/config /home/user/.config/sway/config
fi



# --- 4. 依存関係のビルド ---

# 4-1. libxslt
echo "===== Building libxslt ====="
DIR=$(download_extract "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz")
cd "$DIR"
./configure --prefix=/usr --disable-static > "$LOG/libxslt.log" 2>&1
make -j"$JOBS" >> "$LOG/libxslt.log" 2>&1
make install >> "$LOG/libxslt.log" 2>&1
ldconfig # [FIX] 追加
cd "$ROOT_DIR"

# 4-2. xmlto (一時的なダミー作成)
# [FIX] /usr/bin 直接ではなく、一時ディレクトリを作成して PATH の先頭に置くのが安全
mkdir -p "$SRC/bin"
cat > "$SRC/bin/xmlto" << "EOF"
#!/bin/sh
exit 0
EOF
chmod +x "$SRC/bin/xmlto"
export PATH="$SRC/bin:$PATH"

# 4-3. shared-mime-info
git config --global http.sslVerify false
build_meson "shared-mime-info" "https://gitlab.freedesktop.org/xdg/shared-mime-info.git" ""
chmod -R ugo+rX /usr/share/mime
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
    "-Dbuiltin_loaders=all -Djpeg=enabled -Dothers=enabled -Dman=false -Dintrospection=disabled -Dtests=false"

# --- 6. swaybg (Final) ---
build_meson "swaybg" "https://github.com/swaywm/swaybg.git" ""

# 後処理
git config --global http.sslVerify true
rm -f "$SRC/bin/xmlto" # [FIX] ダミーの削除

echo "===== ALL PHASES COMPLETE: swaybg is ready ====="
