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

# gsettings-desktop-schemas
build_meson "gsettings-desktop-schemas" \
     "https://download.gnome.org/sources/gsettings-desktop-schemas/49/gsettings-desktop-schemas-49.1.tar.xz" \
     "-Dintrospection=false"

# スキーマをコンパイルしてシステムに認識させる
glib-compile-schemas /usr/share/glib-2.0/schemas

# nghttp2
build_autotools "nghttp2" \
    "https://github.com/nghttp2/nghttp2/releases/download/v1.61.0/nghttp2-1.61.0.tar.xz" \
    "--prefix=/usr \
     --disable-static \
     --enable-lib-only \
     --without-systemd \
     --without-libxml2"

echo "===== Building sqlite ====="
DIR=$(download_extract "https://www.sqlite.org/2024/sqlite-autoconf-3450300.tar.gz")
cd "$DIR"
# 3. 正しい形式で configure (CPPFLAGSを直接引数で渡す)
./configure --prefix=/usr \
            --disable-static \
            --enable-fts5 \
            CPPFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1"
make
make install
cd "$ROOT_DIR"

# ビルド関数または直接実行
build_meson "libsoup" \
    "https://download.gnome.org/sources/libsoup/3.6/libsoup-3.6.1.tar.xz" \
    "--prefix=/usr \
     --buildtype=release \
     -Dintrospection=disabled \
     -Dvapi=disabled \
     -Ddocs=disabled \
     -Dtests=false \
     -Dtls_check=false"

build_autotools "libbytesize" \
    "https://github.com/storaged-project/libbytesize/releases/download/2.10/libbytesize-2.10.tar.gz" \
    "--prefix=/usr --disable-static"

echo "===== Building libaio ====="
DIR=$(download_extract "https://pagure.io/libaio/archive/libaio-0.3.113/libaio-0.3.113.tar.gz")
cd "$DIR"
# 64bit環境向けの修正
sed -i '/install.*libdir/s@/lib@/lib64@g' src/Makefile || true
make prefix=/usr
make prefix=/usr install
ldconfig
cd "$ROOT_DIR"

build_autotools "lvm2" \
    "https://sourceware.org/pub/lvm2/LVM2.2.03.23.tgz" \
    "--prefix=/usr \
     --enable-pkgconfig \
     --enable-cmdlib \
     --enable-dmeventd \
     --disable-static"

cat <<EOF > /usr/lib/pkgconfig/libndctl.pc
Name: libndctl
Description: Dummy libndctl for libblockdev build
Version: 999.999
Libs:
Cflags:
EOF

echo "===== Building dmraid ====="
DIR=$(download_extract "https://people.redhat.com/~heinzm/sw/dmraid/src/dmraid-current.tar.bz2")
cd "$DIR/1.0.0.rc16-3/dmraid"
echo "$DIR/1.0.0.rc16-3/dmraid"

# 1. ソースコードの物理修正（再確認）
sed -i 's/ssize_t(\*func) (.*);/ssize_t(*func) (int, void *, size_t);/g' lib/misc/file.c
sed -i '864c\do_device(struct lib_context *lc, struct raid_set *rs, int (*f) (char *, char *))' lib/activate/activate.c
# 2. Makefile の書き換え（これが重要！）
# lib/Makefile.in 内の SUBDIRS から events を消去し、ビルド対象から物理的に除外します
sed -i 's/SUBDIRS = .*/SUBDIRS = ./' lib/Makefile.in
sed -i 's/TARGETS += .*/TARGETS = libdmraid.a libdmraid.so/' lib/Makefile.in
# 3. 設定のリセットと再構成
export CFLAGS="-O2 -fpermissive -Wno-error=all ${CFLAGS:-}"
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --enable-libselinux=no \
            --enable-libsepol=no \
            --disable-events
make
make install
ldconfig
cd "$ROOT_DIR"

echo "===== Building NSPR  ====="
DIR=$(download_extract "https://archive.mozilla.org/pub/nspr/releases/v4.35/src/nspr-4.35.tar.gz")
cd "$DIR/nspr"
echo "$DIR/nspr"
./configure --prefix=/usr \
            --with-mozilla \
            --with-pthreads \
            $([ $(uname -m) = x86_64 ] && echo --enable-64bit)
make
make install

echo "===== Building NSS (The Crypto Engine) ====="
DIR=$(download_extract "https://archive.mozilla.org/pub/security/nss/releases/NSS_3_121_RTM/src/nss-3.121.tar.gz")
cd "$DIR/nss"
echo "$DIR/nss"
make -j$(nproc) BUILD_OPT=1 \
    NSPR_INCLUDE_DIR=/usr/include/nspr \
    USE_64=1 \
    $( [ -f /usr/include/sqlite3.h ] && echo NSS_USE_SYSTEM_SQLITE=1 )


# 3. ディレクトリ作成
install -v -m755 -d /usr/include/nss
cd ../dist
install -v -m644 public/nss/*.h /usr/include/nss/
cd Linux6.16_x86_64_cc_glibc_PTH_64_OPT.OBJ
# 4. ライブラリとチェックファイルの配置
install -v -m755 lib/*.so /usr/lib/
install -v -m644 lib/*.chk /usr/lib/
install -v -m644 lib/*.a /usr/lib/
# 6. 実行ファイルの配置（certutil など、後で使うかもしれません）
install -v -m755 bin/* /usr/bin/
cat > /usr/lib/pkgconfig/nss.pc << "EOF"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include/nss
Name: NSS
Description: Network Security Services
Version: 3.121
Requires: nspr >= 4.35
Libs: -L${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
Cflags: -I${includedir}
EOF
ldconfig

echo "===== Building keyutils ====="
DIR=$(download_extract "https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git/snapshot/keyutils-1.6.3.tar.gz")
cd "$DIR"
make
make DESTDIR=/ install
ldconfig


build_autotools "popt" \
    "http://ftp.rpm.org/popt/releases/popt-1.x/popt-1.19.tar.gz" \
    "--prefix=/usr --disable-static"

echo "===== Building Cryptsetup (LUKS Support) ====="
DIR=$(download_extract "https://www.kernel.org/pub/linux/utils/cryptsetup/v2.4/cryptsetup-2.4.3.tar.xz")
cd "$DIR"
./configure --prefix=/usr \
            --disable-static \
            --disable-ssh-token \
            --with-crypto_backend=openssl # または nss
make
make install
ldconfig

build_meson "libnvme" \
    "https://github.com/linux-nvme/libnvme/archive/v1.15/libnvme-1.15.tar.gz" \
    ""

# libatasmart
build_autotools "libatasmart" \
    "http://0pointer.de/public/libatasmart-0.19.tar.xz" \
    "--prefix=/usr --disable-static"

# libyaml
build_autotools "libyaml" \
    "http://pyyaml.org/download/libyaml/yaml-0.1.7.tar.gz" \
    "--prefix=/usr --disable-static"

echo "===== Building libblockdev  ====="
DIR=$(download_extract "https://ftp.lfs-matrix.net/pub/blfs/12.4/l/libblockdev-3.3.1.tar.gz")
cd "$DIR"
# 1. 問題の nvdimm.c を空のファイルで上書きする
# これにより、依存関係（.h等）を一切無視して「中身なし」でコンパイルが終わります
echo "int bd_nvdimm_is_vmem_enabled (void) { return 0; }" > src/plugins/nvdimm.c
echo "" > src/plugins/nvdimm.h
# 2. configure 実行（これまでと同じ設定）
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --with-loop \
            --with-fs \
            --with-part \
            --with-nvme \
            --without-lvm \
            --without-dm \
            --with-crypto \
            --with-mdraid \
            --without-mpath \
            --without-tools \
            --without-escrow \
            --disable-static \
            --disable-introspection
# 3. ビルドとインストール
# nvdimm が Makefile から消えているので、先ほどのエラー箇所は読み飛ばされます
make
make install
cd "$ROOT_DIR"

echo "===== Building udisks2 (Forcing MDRAID-skip) ====="
DIR=$(download_extract "https://github.com/storaged-project/udisks/releases/download/udisks-2.10.1/udisks-2.10.1.tar.bz2")
cd "$DIR"
# configure スクリプト内の MDRAID チェック箇所をコメントアウトする
# "pkg_modules" 変数に blockdev-mdraid が含まれている行を無効化
sed -i 's/blockdev-mdraid >=/disable-mdraid-check >=/g' configure
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --disable-static \
            --enable-daemon \
            --disable-man \
            --disable-btrfs \
            --disable-lvm2 \
            --disable-zram \
            --disable-encryption \
            --disable-introspection \
            --disable-vapi \
            --without-bash-completion \
            --with-systemdsystemunitdir=no

# ビルドとインストール
make
make install
ldconfig
cd "$ROOT_DIR"

# libusb
build_autotools "libusb" \
    "https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.tar.bz2" \
    "--prefix=/usr --disable-static"

# libarchive
build_autotools "libarchive" \
    "https://github.com/libarchive/libarchive/releases/download/v3.8.1/libarchive-3.8.1.tar.xz" \
    "--prefix=/usr --disable-static"

# libcdio
build_autotools "libcdio" \
    "https://ftp.gnu.org/gnu/libcdio/libcdio-2.1.0.tar.bz2" \
    "--prefix=/usr --disable-static"

# libcdio-paranoia
build_autotools "libcdio-paranoia" \
    "https://ftp.gnu.org/gnu/libcdio/libcdio-paranoia-10.2+2.0.2.tar.bz2" \
    "--prefix=/usr --disable-static"


# gvfs
build_meson "gvfs" \
     "https://download.gnome.org/sources/gvfs/1.56/gvfs-1.56.1.tar.xz" \
     "--prefix=/usr \
     --buildtype=release \
     -Dsmb=false \
     -Dgphoto2=false \
     -Dmtp=false \
     -Dbluray=false \
     -Ddnssd=false \
     -Dgcr=false \
     -Dkeyring=false \
     -Dgoa=false \
     -Dafc=false \
     -Dfuse=false \
     -Donedrive=false \
     -Dnfs=false \
     -Dgoogle=false \
     -Dman=false"

# root権限で実行
ln -sf /usr/lib/gvfs/libgvfscommon.so /usr/lib/gio/modules/
ln -sf /usr/lib/gvfs/libgvfsdaemon.so /usr/lib/gio/modules/

# モジュールキャッシュの更新（必須）
gio-querymodules /usr/lib/gio/modules

# libfm-extra
build_autotools "libfm-extra" \
    "https://downloads.sourceforge.net/pcmanfm/libfm-1.3.2.tar.xz" \
    "--sysconfdir=/etc \
     --prefix=/usr \
     --disable-static \
     --with-extra-only"

# menu-cache
build_autotools "menu-cache" \
    "https://downloads.sourceforge.net/lxde/menu-cache-1.1.0.tar.xz" \
    "CFLAGS=-fcommon \
     --prefix=/usr \
     --disable-static"

# 最も確実な方法：先に環境変数をセットしておく
export CFLAGS="-fcommon -Wno-error=incompatible-pointer-types"

# libfm (GCC 15 対策版)
echo "===== Building libfm (GCC 15 Fix) ====="
DIR=$(download_extract "https://downloads.sourceforge.net/pcmanfm/libfm-1.3.2.tar.xz")
cd "$DIR"
# CFLAGS に GCC 15 の厳格なチェックを回避する魔法のフラグを追加
# -fpermissive は C++ 用ですが、C では -Wno-error=... 系のフラグが有効です
export CFLAGS="-g -O2 -std=gnu99 -Wno-error=incompatible-pointer-types -Wno-discarded-qualifiers"
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --with-gtk=3 \
            --with-gvfs > "$LOG/libfm.log" 2>&1

make -j"$JOBS" >> "$LOG/libfm.log" 2>&1
make install >> "$LOG/libfm.log" 2>&1
ldconfig
cd "$ROOT_DIR"
# インストール後のキャッシュ更新

# PCManFM のビルド
echo "===== pcmanfm ====="
DIR=$(download_extract "https://downloads.sourceforge.net/pcmanfm/pcmanfm-1.3.2.tar.xz")
cd "$DIR"
# 5. 再構成（ログをしっかり取る）
./configure --prefix=/usr --sysconfdir=/etc --with-gtk=3  > "$LOG/pcmanfm.log" 2>&1
# 6. ビルド（Z840の全コア投入）
make -j$(nproc) >> "$LOG/pcmanfm.log" 2>&1
# 7. インストール
make install >> "$LOG/pcmanfm.log" 2>&1
# 共有ライブラリのキャッシュを更新
ldconfig

# gdk-pixbuf のローダーキャッシュを強制更新
gdk-pixbuf-query-loaders --update-cache

update-mime-database /usr/share/mime

# Libfm のビルド
#build_autotools "libfm" \
#    "https://downloads.sourceforge.net/pcmanfm/libfm-1.3.2.tar.xz" \
#    "--prefix=/usr \
#     --sysconfdir=/etc \
#     --with-gtk=3 \
#     --with-gvfs \
#     --disable-static"


# PCManFM のビルド
#build_autotools "pcmanfm" \
#    "https://downloads.sourceforge.net/pcmanfm/pcmanfm-1.3.2.tar.xz" \
#    "--prefix=/usr \
#     --sysconfdir=/etc \
#     --with-gtk=3"



echo "=================================================="
echo "    13 GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - PCMAN                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
