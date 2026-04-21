#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"

# 共通関数の読み込み
if [ -f "./common.sh" ]; then
    source "./common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

echo "===== Building lsof ====="
cd "$SRC"
wget https://github.com/lsof-org/lsof/releases/download/4.99.6/lsof-4.99.6.tar.gz
tar -xf lsof-4.99.6.tar.gz
cd lsof-4.99.6
./configure
make

install -v -m0755 -s lsof /usr/bin
install -v -m0644 Lsof.8 /usr/share/man/man8

cd "$ROOT_DIR"

echo "===== Building unzip ====="
cd "$SRC"
wget https://downloads.sourceforge.net/infozip/unzip60.tar.gz
tar -xf unzip60.tar.gz
cd unzip60
# 2. 前回の gmtime エラーの修正だけを適用（これだけで十分です）
sed -i 's/struct tm \*gmtime(), \*localtime();/\/* struct tm *gmtime(), *localtime(); *\//' unix/unxcfg.h
gcc -c -I. -Ibzip2 -DUNIX -O3 -DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DHAVE_DIRENT_H -DHAVE_TERMIOS_H *.c unix/unix.c
# 1. unzip本体に関係ない、別の「main」を持つファイルを削除
rm -f funzip.o gbloffs.o unzipstb.o unzipsfx.o
gcc -o unzip *.o -lbz2
cp -v unzip /usr/bin/
cd "$ROOT_DIR"

echo "===== Building pgrep ====="

cd "$SRC"
wget https://downloads.sourceforge.net/project/procps-ng/Production/procps-ng-4.0.5.tar.xz
tar -xf procps-ng-4.0.5.tar.xz
cd procps-ng-4.0.5

sed -i '62i #include <stdbool.h>' src/watch.c

./configure

make

make install

cd "$ROOT_DIR"

# 1. pciutils
echo "===== Building PCIUTILS ====="
cd "$SRC"
wget https://mj.ucw.cz/download/linux/pci/pciutils-3.14.0.tar.gz
tar xf pciutils-3.14.0.tar.gz
cd pciutils-3.14.0

# 2. ビルド設定
# PREFIX=/usr: 標準のシステムパスにインストール
# SHARED=yes: Firefoxが必要とする共有ライブラリ（libpci.so）を生成
# LIBDIR=/usr/lib: 64bit環境のライブラリパスを指定
make PREFIX=/usr                \
     SHAREDIR=/usr/share/hwdata \
     SHARED=yes                 \
     LIBDIR=/usr/lib            \
     HOST=x86_64-linux          \
     OPT="-march=native -O2"

# 3. インストール（root権限で実行）
# 共有ライブラリのインストールを確実にするため install-lib も実行
make PREFIX=/usr                \
     SHAREDIR=/usr/share/hwdata \
     SHARED=yes                 \
     LIBDIR=/usr/lib            \
     install install-lib

# 4. 共有ライブラリの認識を更新
ldconfig

# 5. PCI ID データベースの更新（ネットワークが必要）
# これにより最新のGPU名などが正しく表示されます
update-pciids


echo "===== gdb ====="
cd "$SRC"

wget https://ftp.gnu.org/gnu/gdb/gdb-16.3.tar.xz

rm -rf gdb-16.3

tar -xf gdb-16.3.tar.xz

cd gdb-16.3

export CXXFLAGS="${CXXFLAGS:-} -fpermissive -D_GLIBCXX_HAVE_STDBOOL_H -DNCURSES_BOOL=bool"
export CPPFLAGS="${CPPFLAGS:-} -DNCURSES_NOMACROS"

./configure --prefix=/usr \
            --with-system-readline \
            --with-python=/usr/bin/python3 \
            --disable-source-highlight

# --disable-tui

make

make install

echo "===== PCIUTILS installation completed! ====="
