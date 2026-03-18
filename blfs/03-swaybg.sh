#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"

# --- 2. ユーティリティ関数（既存） ---
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

# --- 3. Sway初期設定 & フォント配置 ---
echo "===== Configuring Sway & Fonts ====="
# ユーザー設定ディレクトリの準備
mkdir -pv ~/.config/sway
if [ -f /etc/sway/config ]; then
    cp -v /etc/sway/config ~/.config/sway/config
fi

# フォントの配置 (DejaVu)
mkdir -p /usr/share/fonts/truetype/dejavu
cp /tmp/*.ttf /usr/share/fonts/truetype/dejavu/ 2>/dev/null || true

# フォントの配置 (Noto)
mkdir -p /usr/share/fonts/truetype/noto
cp /tmp/*.ttf /usr/share/fonts/truetype/noto/ 2>/dev/null || true

# フォントキャッシュの更新
fc-cache -fv
echo "Monospace font match:"
fc-match monospace

# --- 4. 依存関係のビルド (libxslt -> xmlto -> shared-mime-info) ---

# 4-1. libxslt
echo "===== Building libxslt ====="
DIR=$(download_extract "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz")
cd "$DIR"
./configure --prefix=/usr --disable-static > "$LOG/libxslt.log" 2>&1
make -j"$JOBS" >> "$LOG/libxslt.log" 2>&1
make install >> "$LOG/libxslt.log" 2>&1
cd "$ROOT_DIR"

# 4-2. xmlto (ダミースクリプトの作成)
# ビルド依存を解決するためのプレースホルダ
echo "===== Creating dummy xmlto ====="
cat > /usr/bin/xmlto << "EOF"
#!/bin/sh
echo "Dummy xmlto called with: $@"
exit 0
EOF
chmod +x /usr/bin/xmlto

# 4-3. shared-mime-info (Git版)
echo "===== Building shared-mime-info ====="
cd "$SRC"
rm -rf shared-mime-info
git config --global http.sslVerify false
git clone https://gitlab.freedesktop.org/xdg/shared-mime-info.git
cd shared-mime-info
meson setup build --prefix=/usr --buildtype=release > "$LOG/shared-mime-info.log" 2>&1
ninja -C build >> "$LOG/shared-mime-info.log" 2>&1
ninja -C build install >> "$LOG/shared-mime-info.log" 2>&1
chmod -R ugo+rX /usr/share/mime
update-mime-database /usr/share/mime
ldconfig
cd "$ROOT_DIR"

# --- 5. 画像処理スタック (libjpeg-turbo -> gdk-pixbuf) ---

# 5-1. libjpeg-turbo
echo "===== Building libjpeg-turbo ====="
DIR=$(download_extract "https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz")
cd "$DIR"
rm -rf build && mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr           \
      -D CMAKE_BUILD_TYPE=RELEASE            \
      -D ENABLE_STATIC=FALSE                 \
      -D CMAKE_INSTALL_DEFAULT_LIBDIR=lib    \
      -D CMAKE_SKIP_INSTALL_RPATH=ON         \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5    \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo-3.0.1 \
      .. > "$LOG/libjpeg-turbo.log" 2>&1
make -j"$JOBS" >> "$LOG/libjpeg-turbo.log" 2>&1
make install >> "$LOG/libjpeg-turbo.log" 2>&1
cd "$ROOT_DIR"

# 5-2. gdk-pixbuf (Git版)
echo "===== Building gdk-pixbuf ====="
cd "$SRC"
rm -rf gdk-pixbuf
git clone https://gitlab.gnome.org/GNOME/gdk-pixbuf.git
cd gdk-pixbuf
meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dbuiltin_loaders=none \
    -Dothers=enabled \
    -Dman=false \
    -Dintrospection=disabled \
    -Dglycin=disabled \
    -Dtests=false > "$LOG/gdk-pixbuf.log" 2>&1
ninja -C build >> "$LOG/gdk-pixbuf.log" 2>&1
ninja -C build install >> "$LOG/gdk-pixbuf.log" 2>&1
cd "$ROOT_DIR"

# --- 6. swaybg (Final) ---
echo "===== Building swaybg ====="
cd "$SRC"
rm -rf swaybg
git clone https://github.com/swaywm/swaybg.git
cd swaybg
meson setup build --prefix=/usr --buildtype=release > "$LOG/swaybg.log" 2>&1
ninja -C build >> "$LOG/swaybg.log" 2>&1
ninja -C build install >> "$LOG/swaybg.log" 2>&1

# Git設定を元に戻す
git config --global http.sslVerify true

echo "===== ALL PHASES COMPLETE: swaybg is ready ====="
