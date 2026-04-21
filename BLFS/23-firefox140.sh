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


cp /root/.cargo/bin/rustc /usr/bin/rustc
cp /root/.cargo/bin/cargo /usr/bin/cargo
cp /root/.cargo/bin/rustup /usr/bin/rustup

# 全ユーザーが実行できるように権限を設定
chmod +x /usr/bin/rustup /usr/bin/rustc /usr/bin/cargo
su - user -c "rustup default stable"
# user に切り替えてインストール
su - user -c "cargo install cbindgen"

build_autotools libevent "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz" ""


# --- 2. Firefox 専用ビルド処理 ---
FIREFOX_URL="https://archive.mozilla.org/pub/firefox/releases/140.9.0esr/source/firefox-140.9.0esr.source.tar.xz"
TAR_NAME="firefox-140.9.0esr.source.tar.xz"
NAME="firefox-140.9.0" # 解凍後のディレクトリ名に合わせる

echo "===== Building $NAME ====="
cd "$SRC"
rm -rf firefox-140.9.0
[ -f "$TAR_NAME" ] || wget "$FIREFOX_URL"
tar xf "$TAR_NAME"
cd "$NAME"

# 念のため .mozconfig にフルパスを教える
echo "ac_add_options --with-rustc=/usr/bin/rustc" >> "$SRC/firefox-140.9.0/.mozconfig"
echo "ac_add_options --with-cargo=/usr/bin/cargo" >> "$SRC/firefox-140.9.0/.mozconfig"

# 重要：一般ユーザーがビルドできるように所有権を変更
chown -R user:user .

# 3. .mozconfig の作成
# 注意：MOZ_OBJDIR は mk_add_options の独立した行にする必要があります
cat << EOF > .mozconfig
ac_add_options --prefix=/usr
ac_add_options --enable-application=browser
ac_add_options --enable-optimize="-O2 -march=native"
ac_add_options --enable-release

# ビルドディレクトリ
mk_add_options MOZ_OBJDIR=/tmp/firefox-build
# Z840ならメモリに余裕があるはずですが、リンク時のメモリ消費が激しいので -j4 程度は賢明です
mk_add_options MOZ_MAKE_FLAGS="-j4"

# --- マルチメディア関連 (ここが重要) ---
# システムの ffmpeg を使うことを明示 (AAC/MP4再生に必須)
ac_add_options --with-system-libvpx
ac_add_options --with-system-ffi

# --- グラフィックス関連 ---
# Wayland サポートを確実に有効化
ac_add_options --enable-default-toolkit=cairo-gtk3-wayland



# バックエンドをALSAだけに固定することで、自動推論による衝突を防ぐ
ac_add_options --enable-audio-backends=alsa

# --- 不要な機能の無効化 (ビルド時間短縮) ---
ac_add_options --disable-tests
ac_add_options --disable-debug
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-accessibility
ac_add_options --disable-gecko-profiler
ac_add_options --without-wasm-sandboxed-libraries

# Rust最適化
ac_add_options --enable-rust-simd
mk_add_options MOZ_RUST_DEFAULT_FLAGS="-C target-cpu=native"
EOF


# 所有権を再度確認（.mozconfig を root が作った場合に備えて）
chown user:user .mozconfig

echo "Starting Firefox build (This may take a while)..."

wget https://www.linuxfromscratch.org/patches/blfs/svn/firefox-140.9.0esr-ffmpeg-8.0.patch
wget https://www.linuxfromscratch.org/patches/blfs/svn/firefox-140.9.0esr-glibc-2.43.patch
wget https://www.linuxfromscratch.org/patches/blfs/svn/firefox-140.9.0esr-python_3.14_fixes-1.patch
wget https://www.linuxfromscratch.org/patches/blfs/svn/firefox-140.9.0esr-llvm_22-1.patch

patch -Np1 -i firefox-140.9.0esr-llvm_22-1.patch
patch -Np1 -i firefox-140.9.0esr-glibc-2.43.patch
patch -Np1 -i firefox-140.9.0esr-python_3.14_fixes-1.patch
patch -Np1 -i firefox-140.9.0esr-ffmpeg-8.0.patch
# 2. Cargoの設定をローカル参照に切り替え
sed '/patch.crates-io/a glslopt={path="third_party/rust/glslopt"}' \
    -i Cargo.toml

# 3. ロックファイルから古いチェックサム情報を削除
sed '/name = "glslopt"/,/^$/{/source/d;/checksum/d}' -i Cargo.lock

echo "Applying full SIMD mask..."

# Z840のCPU機能を全開放する
export CFLAGS="-march=native -DSYS_SECCOMP=317"
export CXXFLAGS="-march=native -DSYS_SECCOMP=317"
# Rustのbindgen（Clang呼び出し）にも、この「意志」を伝える
export BINDGEN_EXTRA_CLANG_ARGS="-march=native"
# もしLFS環境でターゲットトリプルに厳格なら、以下も併用
export BINDGEN_EXTRA_CLANG_ARGS="$BINDGEN_EXTRA_CLANG_ARGS -target x86_64-unknown-linux-gnu"

# 1. 物理ディスク上のビルドディレクトリを準備
# (メモリ溢れを防ぐため、ソースツリー内に置くのがLFSでは安全です)
OBJDIR="$SRC/firefox-140.9.0/obj-firefox"
mkdir -p "$OBJDIR"
chown -R user:user "$OBJDIR"
chown -R user:user "$SRC/firefox-140.9.0"

# 2. .mozconfig の OBJDIR を物理ディスクに書き換え
# (もし /tmp/firefox-build になっていたら、ここを物理パスに！)
sed -i "s|mk_add_options MOZ_OBJDIR=.*|mk_add_options MOZ_OBJDIR=$OBJDIR|" .mozconfig

echo "Cleaning up permissions..."
rm -rf /tmp/firefox-build  # 念のため古い残骸を消去

echo "Building... (Log: tail -f $LOG/firefox.log)"

export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig

# su - user -c '...' を使う
# -m (preserve environment) は使わず、ログインシェルで実行するのが一番安定します
su - user -c "
    cd $SRC/firefox-140.9.0 && \
    export PATH=\$PATH:/home/user/.cargo/bin && \
    export CFLAGS='-march=native -DSYS_SECCOMP=317' && \
    export CXXFLAGS='-march=native -DSYS_SECCOMP=317' && \
    export BINDGEN_EXTRA_CLANG_ARGS='-march=native -target x86_64-unknown-linux-gnu' && \
    export RUSTC=/usr/bin/rustc && \
    export CARGO=/usr/bin/cargo && \
    ./mach build" >> "$LOG/firefox.log" 2>&1

# 5. インストール（root権限）
echo "Installing Firefox..."
./mach install >> "$LOG/firefox.log" 2>&1

ldconfig
cd "$ROOT_DIR"

echo "===== FIREFOX COMPLETED ====="

