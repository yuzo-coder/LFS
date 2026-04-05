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

# --- 2. Firefox 専用ビルド処理 ---
FIREFOX_URL="https://archive.mozilla.org/pub/firefox/releases/140.9.0esr/source/firefox-140.9.0esr.source.tar.xz"
TAR_NAME="firefox-140.9.0esr.source.tar.xz"
NAME="firefox-140.9.0" # 解凍後のディレクトリ名に合わせる

echo "===== Building $NAME ====="
cd "$SRC"
[ -f "$TAR_NAME" ] || wget "$FIREFOX_URL"
tar xf "$TAR_NAME"
cd "$NAME"

# 念のため .mozconfig にフルパスを教える
echo "ac_add_options --with-rustc=/usr/bin/rustc" >> /LFSAutoBuilder/blfs/sources/firefox-140.9.0/.mozconfig
echo "ac_add_options --with-cargo=/usr/bin/cargo" >> /LFSAutoBuilder/blfs/sources/firefox-140.9.0/.mozconfig

# 重要：一般ユーザーがビルドできるように所有権を変更
chown -R user:user .

# 3. .mozconfig の作成
# 注意：MOZ_OBJDIR は mk_add_options の独立した行にする必要があります
cat << EOF > .mozconfig
ac_add_options --prefix=/usr
ac_add_options --enable-application=browser
ac_add_options --enable-optimize
ac_add_options --enable-release
# ★重要：MOZ_OBJDIR を独立させ、メモリ(tmpfs)を指定
mk_add_options MOZ_OBJDIR=/tmp/firefox-build
mk_add_options MOZ_MAKE_FLAGS="-j$(nproc)"
# 全コアではなく、メモリ 8GB なら 2〜4 程度に抑えるのが安全です
mk_add_options MOZ_MAKE_FLAGS="-j4"

# システムライブラリの利用
# ac_add_options --with-system-icu
ac_add_options --with-system-zlib
ac_add_options --with-system-webp
# ac_add_options --with-system-png
ac_add_options --with-system-jpeg
ac_add_options --with-system-libvpx
ac_add_options --with-system-ffi
ac_add_options --enable-alsa
ac_add_options --enable-pulseaudio
ac_add_options --disable-tests
ac_add_options --disable-debug
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --without-wasm-sandboxed-libraries
ac_add_options --disable-gecko-profiler
ac_add_options --target=x86_64-pc-linux-gnu
ac_add_options --host=x86_64-pc-linux-gnu
ac_add_options --with-toolchain-prefix=x86_64-pc-linux-gnu-
# Rustの最適化レベルを上げる
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

# 4. ビルド実行
# HOME を指定することで /root/.mozbuild へのアクセスを回避します
echo "Cleaning up..."
su -m user -c "HOME=/home/user ./mach clobber" > "$LOG/firefox.log" 2>&1

echo "Building... (Log: tail -f $LOG/firefox.log)"
# RUSTUP_TOOLCHAIN=stable を加えることで、rustup 経由のチェックを強制通過させます
# su コマンドの中で直接環境変数をセットして実行
su -m user -c "HOME=/home/user \
    PATH=\$PATH:/home/user/.cargo/bin \
    CFLAGS='-march=native -DSYS_SECCOMP=317' \
    CXXFLAGS='-march=native -DSYS_SECCOMP=317' \
    BINDGEN_EXTRA_CLANG_ARGS='-march=native -target x86_64-unknown-linux-gnu' \
    RUSTC=/usr/bin/rustc \
    CARGO=/usr/bin/cargo \
    ./mach build" >> "$LOG/firefox.log" 2>&1

# 5. インストール（root権限）
echo "Installing Firefox..."
./mach install >> "$LOG/firefox.log" 2>&1

ldconfig
cd "$ROOT_DIR"

# ビルドが終わったら後始末（スクリプトの最後に）
umount /usr/lib/clang/18/include/mmintrin.h
echo "===== FIREFOX COMPLETED ====="

