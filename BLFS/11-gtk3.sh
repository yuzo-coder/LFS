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
    "https://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz" \
    "--disable-oss --disable-lynx --disable-tdb --disable-gtk --disable-gtk3"

# 2. pavucontrol (PulseAudio Volume Control)
# ※ C++ のモダンな実装のため、sigc++ や gtkmm などの C++ ラッパーが必要です。
# BLFS 環境で不足している場合は Meson が自動でチェックします。
build_meson "pavucontrol" \
    "https://freedesktop.org/software/pulseaudio/pavucontrol/pavucontrol-6.0.tar.xz" \
    "-Dlynx=false"


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

# 3. libnma (nm-connection-editor のコアライブラリ)
# ネットワーク設定の GUI コンポーネントを提供します。
build_meson "libnma" \
    "https://download.gnome.org/sources/libnma/1.10/libnma-1.10.6.tar.xz" \
    "-Dintrospection=false -Dgtk_doc=false -Dgcr=false -Dvapi=false"

# 1. libgpg-error (libgcrypt の前提ライブラリ)
DIR=$(download_extract "https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.47.tar.bz2")
cd "$DIR"
echo "$DIR"
# 'nullptr' という変数名を 'my_nullptr' に一括置換する
sed -i 's/nullptr/my_nullptr/g' tests/t-printf.c
# 【重要】Makefile を生成するために configure を実行
./configure --prefix=/usr --disable-static >> /LFSAutoBuilder/blfs/logs/libgpg-error.log 2>&1
make -j$(nproc) >> /LFSAutoBuilder/blfs/logs/libgpg-error.log 2>&1
make install >> /LFSAutoBuilder/blfs/logs/libgpg-error.log 2>&1
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
build_meson "cairo" \
    "https://www.cairographics.org/releases/cairo-1.18.0.tar.xz" \
    "-Dxlib=enabled \
     -Dxcb=enabled \
     -Dtests=disabled \
     -Dglib=enabled"

# 2. 確実にインストールされた実体ファイルがあるかチェック
if [ -f "/usr/lib/libcairo.so.2.11800.0" ]; then
    echo "Confirmed: Cairo 1.18.0 (X11 enabled) installed."
    
    # 古いリンクを削除して張り直す
    rm -f /usr/lib/libcairo.so /usr/lib/libcairo.so.2
    
    # 相対パスでリンクを張る（推奨される作法です）
    cd /usr/lib
    ln -sf libcairo.so.2.11800.0 libcairo.so
    ln -sf libcairo.so.2.11800.0 libcairo.so.2
    cd - > /dev/null
    
    ldconfig
else
    echo "Error: libcairo.so.2.11800.0 not found. Check build logs."
    exit 1
fi
cd "$ROOT_DIR"

# GTK3 (--enable-x11-backend)
build_meson gtk3 "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.41.tar.xz" \
    "-Dwayland_backend=true -Dx11_backend=true -Dintrospection=false -Ddemos=false -Dtests=false -Dexamples=false -Dcolord=no"

# network-manager-applet (GUI設定ツール本体)
build_meson "network-manager-applet" \
    "https://download.gnome.org/sources/network-manager-applet/1.34/network-manager-applet-1.34.0.tar.xz" \
     "-Dwwan=false \
     -Dselinux=false \
     -Dappindicator=no \
     -Dteam=false"

echo "=================================================="
echo "    GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - pavucontrol (Volume)                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
