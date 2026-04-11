#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
TARGET_USER="user" # 一般ユーザー名

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# 1. libogg (Vorbis の基礎となるコンテナフォーマット)
build_autotools "libogg" \
    "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz" \
    "--disable-static"

# 2. libvorbis (これが 'vorbisfile' を提供します)
build_autotools "libvorbis" \
    "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz" \
    "--disable-static"


# --- 5. GUI 管理ツール (pavucontrol & nm-connection-editor) ---

# 1. libcanberra (pavucontrol の音量フィードバック音に必要)
# ※ GUI アプリの動作を安定させるために推奨されます
build_autotools "libcanberra" \
    "https://ftp.lfs-matrix.net/pub/blfs/12.4/l/libcanberra-0.30.tar.xz" \
    "--disable-oss --disable-lynx --disable-tdb --disable-gtk --disable-gtk3"

# iso-codes (国名・言語コードの標準データ)
# configure 時に --prefix を指定するだけでOKです

# 1. 翻訳データのリンクが衝突している場所を削除
# (各言語の LC_MESSAGES 内にある iso-codes 関連ファイルを消去)
find /usr/share/locale -name "iso_*.mo" -delete

# 2. XML データのインストール先を削除
rm -rf /usr/share/xml/iso-codes
build_autotools "iso-codes" \
    "https://ftp.debian.org/debian/pool/main/i/iso-codes/iso-codes_4.18.0.orig.tar.xz" \
    ""

build_autotools libxslt "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz" "--disable-static"

# mobile-broadband-provider-info (モバイル回線設定データベース)
build_meson "mobile-broadband-provider-info" \
    "https://download.gnome.org/sources/mobile-broadband-provider-info/20240407/mobile-broadband-provider-info-20240407.tar.xz" \
    ""


# Duktape (Polkitのルール評価用エンジン)
echo "===== Building duktape  ====="
DIR=$(download_extract "https://duktape.org/duktape-2.7.0.tar.xz")
cd "$DIR"
# 共有ライブラリとしてビルド
# Makefile.sharedlibrary を使用します
make -f Makefile.sharedlibrary
# インストール (PREFIXを指定)
make -f Makefile.sharedlibrary install INSTALL_PREFIX=/usr
cd ..

# Polkit (権限管理フレームワーク)
# 依存関係を最小限にしてビルドを通します
build_meson "polkit" \
    "https://github.com/polkit-org/polkit/archive/refs/tags/124.tar.gz" \
    "-Dintrospection=false -Dman=false -Dexamples=false -Dgtk_doc=false -Dtests=false"

# 1. libndp (隣接デバイス発見プロトコル - NMに必須)
build_autotools "libndp" \
    "https://libndp.org/files/libndp-1.9.tar.gz" ""


# nspr 
#echo "===== Building nspr ====="
#DIR=$(download_extract "https://archive.mozilla.org/pub/nspr/releases/v4.35/src/nspr-4.35.tar.gz")
#echo "$DIR/nspr"
#cd "$DIR/nspr"
#./configure --prefix=/usr \
#            --with-mozilla \
#            --with-pthreads \
#            $( [ $(uname -m) = x86_64 ] && echo --enable-64bit ) \
#            > /LFSAutoBuilder/blfs/logs/nspr.log 2>&1

#make -j$(nproc) >> /LFSAutoBuilder/blfs/logs/nspr.log 2>&1
#make install >> /LFSAutoBuilder/blfs/logs/nspr.log 2>&1
#ldconfig
#cd "$ROOT_DIR"

# nss (Network Security Services)
# (ダウンロードと展開は download_extract 関数を流用)
#echo "===== Building nss ====="
#DIR=$(download_extract "https://archive.mozilla.org/pub/security/nss/releases/NSS_3_115_RTM/src/nss-3.115.tar.gz")
#cd "$DIR/nss"

# システムにインストール済みの NSPR を使うように指定
#jmake -j$(nproc) nss_build_all \
#    BUILD_OPT=1 \
#    USE_64=1 \
#    USE_SYSTEM_NSPR=1 \
#    NSS_USE_SYSTEM_SQLITE=1 \
#    >> /LFSAutoBuilder/blfs/logs/nss.log 2>&1

# インストール (少し強引ですが、必要な場所へ配置)
#cd ../dist
#cp -vL bin/* /usr/bin/
#cp -vL lib/*.so /usr/lib/
#cp -vL lib/*.chk /usr/lib/
#mkdir -pv /usr/include/nss
#cp -vRL public/nss/* /usr/include/nss/

# 1. nettle (GnuTLSの数学ライブラリ)
build_autotools "nettle" \
    "https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz" \
    "--disable-static"

# 2. GnuTLS本体 (NSPR/NSSの代わり)
build_autotools "gnutls" \
    "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.3.tar.xz" \
    "--with-included-libtasn1 --with-included-unistring --without-p11-kit"

# 3. NetworkManager (GnuTLSを使用するように指定)
#build_meson "NetworkManager" \
#    "https://download.gnome.org/sources/NetworkManager/1.44/NetworkManager-1.44.2.tar.xz" \
#    "-Dintrospection=false -Dqt=false -Dcrypto=gnutls -Dpolkit=yes -Dtests=no"

# libpsl (NetworkManager の依存)
build_autotools "libpsl" \
    "https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz" \
    "--disable-static"

# 2. NetworkManager 本体
# ※ これが "libnm" を提供します。
# Z840 の環境に合わせて、不要な機能（nmtuiの要求するシステム等）は最小限にします。
build_meson "NetworkManager" \
    "https://download.gnome.org/sources/NetworkManager/1.44/NetworkManager-1.44.2.tar.xz" \
    "-Dintrospection=false \
     -Dqt=false \
     -Dlibaudit=no \
     -Dtests=no \
     -Dnmtui=false \
     -Dselinux=false \
     -Dsession_tracking=no \
     -Dsystemd_journal=false \
     -Dppp=false \
     -Dovs=false \
     -Dmodem_manager=false \
     -Dcrypto=gnutls"

# 1. libgpg-error (libgcrypt の前提ライブラリ)
DIR=$(download_extract "https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.47.tar.bz2")
cd "$DIR"
echo "$DIR"
# 'nullptr' という変数名を 'my_nullptr' に一括置換する
sed -i 's/nullptr/my_nullptr/g' tests/t-printf.c
# 【重要】Makefile を生成するために configure を実行
./configure --prefix=/usr --disable-static > "$LOG/libgpg-error.log" 2>&1
make -j$(nproc) >> "$LOG/libgpg-error.log" 2>&1 
make install >> "$LOG/libgpg-error.log" 2>&1
ldconfig
cd "$ROOT_DIR"

# 2. libgcrypt (libsecret の暗号化エンジン)
build_autotools "libgcrypt" \
    "https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.10.3.tar.bz2" \
    "--disable-static"

# libsecret (パスワード管理ライブラリ)
build_meson "libsecret" \
    "https://download.gnome.org/sources/libsecret/0.21/libsecret-0.21.4.tar.xz" \
    "-Dintrospection=false -Dgtk_doc=false -Dvapi=false -Dmanpage=false"

# Cairo (X11 を強制的に有効化)
# 1. Cairo (X11 を強制的に有効化)
#build_meson "cairo" \
#    "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz" \
#    "-Dxlib=enabled \
#     -Dxcb=enabled \
#     -Dtests=disabled \
#     -Dglib=enabled"

echo "===== Building gobject-introspection  ====="
DIR=$(download_extract "https://download.gnome.org/sources/gobject-introspection/1.80/gobject-introspection-1.80.1.tar.xz") 
cd "$DIR"
# MSVCCompiler をダミーのクラスで定義し、NameError を回避する
sed -i 's/from distutils.msvccompiler import MSVCCompiler/class MSVCCompiler: pass/' giscanner/ccompiler.py

export SETUPTOOLS_USE_DISTUTILS=local
meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dbuild_introspection_data=true \
    -Dgtk_doc=false \
    -Ddoctool=disabled \
    -Dpython=python3 > $LOG/gobject.log 2>&1 
ninja -C build -j"$JOBS" >> "$LOG/gobject.log" 2>&1
ninja -C build install >> "$LOG/gobject.log" 2>&1
cd "$ROOT_DIR"

# GLib 2.80.4 の再ビルド
# 依存関係: gobject-introspection がインストール済みであること
build_meson glib2 "https://ftp.lfs-matrix.net/pub/blfs/12.4/g/glib-2.84.4.tar.xz" \
    "-Dintrospection=enabled -Dtests=false"

build_meson atk "https://ftp.lfs-matrix.net/pub/blfs/12.4/a/atk-2.38.0.tar.xz" \
    ""

build_meson "libepoxy" "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" "-Dx11=true -Dglx=yes"

# 2. libepoxy (GPU描画の管理)
# build_meson "libepoxy" \
#    "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" ""

build_meson "at-spi2-core" \
    "https://ftp.lfs-matrix.net/pub/blfs/12.4/a/at-spi2-core-2.56.4.tar.xz" ""

build_meson "at-spi2-atk" \
    "https://download.gnome.org/sources/at-spi2-atk/2.38/at-spi2-atk-2.38.0.tar.xz" ""

build_meson libxkbcommon "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" "-Denable-x11=false"

# GTK3 (--enable-x11-backend)
build_meson gtk3 "https://ftp.lfs-matrix.net/pub/blfs/12.4/g/gtk-3.24.50.tar.xz" \
    "-Dwayland_backend=true -Dx11_backend=true -Dintrospection=false -Ddemos=false -Dtests=false -Dexamples=false -Dcolord=no --wrap-mode=nodownload"

# 3. libnma (nm-connection-editor)
build_meson "libnma" \
    "https://download.gnome.org/sources/libnma/1.10/libnma-1.10.6.tar.xz" \
    "-Dintrospection=false -Dgtk_doc=false -Dgcr=false -Dvapi=false"

# network-manager-applet (GUI設定ツール本体)
build_meson "network-manager-applet" \
    "https://ftp.lfs-matrix.net/pub/blfs/12.4/n/network-manager-applet-1.34.0.tar.xz" \
     "-Dwwan=false \
     -Dselinux=false \
     -Dappindicator=no \
     -Dteam=false"

build_meson xkeyboard-config "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz" ""


# 1. mesa-demos (eglinfo, es2gears_wayland �~I)~
build_meson mesa-demos "https://archive.mesa3d.org/demos/mesa-demos-9.0.0.tar.xz" "-Dwayland=enabled -Dx11=disabled -Dgles2=enabled"

# build_mm_lib atkmm "https://download.gnome.org/sources/atkmm/2.28/atkmm-2.28.4.tar.xz" "-Dbuild-documentation=false -Dlibsigcplusplus:build-documentation=false -Dlibsigcplusplus-2.0:build-documentation=false"

echo "=================================================="
echo "    GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - pavucontrol (Volume)                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
