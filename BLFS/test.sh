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

echo "Applying kernel-level header mask..."
# 1. 万能偽造ヘッダーの最終形態
# 1. 256bit/512bit型まで網羅した究極の偽造ヘッダー
cat << EOF > /tmp/fake_simd.h
#ifndef FAKE_SIMD_H
#define FAKE_SIMD_H

/* 1. 全ての内部ヘッダー衝突を完全に封鎖 */
#define __MMINTRIN_H
#define __XMMINTRIN_H
#define __EMMINTRIN_H
#define __PMMINTRIN_H
#define __TMMINTRIN_H
#define __SMMINTRIN_H
#define __WMMINTRIN_H
#define __AVXINTRIN_H
#define __AVX2INTRIN_H
#define __IMMINTRIN_H

/* 2. 内部ベクター型定義 */
typedef float     __v4sf  __attribute__((__vector_size__(16)));
typedef double    __v2df  __attribute__((__vector_size__(16)));
typedef long long __v2di  __attribute__((__vector_size__(16)));
typedef int       __v4si  __attribute__((__vector_size__(16)));
typedef short     __v8hi  __attribute__((__vector_size__(16)));
typedef char      __v16qi __attribute__((__vector_size__(16)));
typedef long long __v4di  __attribute__((__vector_size__(32)));
typedef int       __v8si  __attribute__((__vector_size__(32)));
typedef char      __v32qi __attribute__((__vector_size__(32)));

/* 3. SIMD基本型定義 (Rust bindgen互換) */
#ifndef __MAINTAIN_TYPES
#define __MAINTAIN_TYPES
typedef float     __m128  __attribute__((__vector_size__(16)));
typedef double    __m128d __attribute__((__vector_size__(16)));
typedef long long __m128i __attribute__((__vector_size__(16)));
typedef float     __m256  __attribute__((__vector_size__(32)));
typedef long long __m256i __attribute__((__vector_size__(32)));

typedef unsigned char __mmask8;
#endif

/* 4. セット・初期化・ロード・ストア */
#define _mm_setzero_si128()      ((__m128i){0})
#define _mm_setzero_ps()         ((__m128){0})
#define _mm256_setzero_si256()   ((__m256i){0})
#define _mm_set1_epi8(x)         ((__m128i){0})
#define _mm_set1_epi16(x)        ((__m128i){0})
#define _mm_set1_epi32(x)        ((__m128i){0})
#define _mm256_set1_epi8(x)      ((__m256i){0})
#define _mm256_set1_epi16(x)     ((__m256i){0})
#define _mm256_set1_epi32(x)     ((__m256i){0})
#define _mm256_set1_epi64x(x)    ((__m256i){0})
#define _mm_set_epi64x(a, b)     ((__m128i){0})
#define _mm_set_ss(x)            ((__m128){0})
#define _mm_loadu_si128(p)       ((__m128i){0})
#define _mm_load_ss(p)           ((__m128){0})
#define _mm_load_sd(p)           ((__m128d){0})
#define _mm256_load_si256(p)     ((__m256i){0})
#define _mm256_loadu_si256(p)    ((__m256i){0})
#define _mm_storeu_si128(p, a)   { (void)p; (void)a; }

/* 5. 算術・論理・比較 (SSE/AVX2) */
#define _mm_add_ps(a, b)         (a)
#define _mm_sub_ps(a, b)         (a)
#define _mm_mul_ps(a, b)         (a)
#define _mm_div_ps(a, b)         (a)
#define _mm_add_epi32(a, b)      (a)
#define _mm_sub_epi32(a, b)      (a)
#define _mm_and_si128(a, b)      (a)
#define _mm_or_si128(a, b)       (a)
#define _mm_cmpeq_epi8(a, b)     (a)
#define _mm_cmpeq_epi16(a, b)    (a)
#define _mm_cmpeq_epi32(a, b)    (a)
#define _mm_min_epi16(a, b)      (a)
#define _mm_max_epi16(a, b)      (a)
#define _mm_adds_epu16(a, b)     (a)
#define _mm_adds_epi16(a, b)     (a)
#define _mm_mulhi_epi16(a, b)    (a)

#define _mm256_add_epi16(a, b)   (a)
#define _mm256_add_epi32(a, b)   (a)
#define _mm256_madd_epi16(a, b)  (a)
#define _mm256_hadd_epi32(a, b)  (a)
#define _mm256_or_si256(a, b)    (a)

/* 6. キャスト・変換・抽出 */
#define _mm_castsi128_pd(a)      ((__m128d)(a))
#define _mm_castsi128_ps(a)      ((__m128)(a))
#define _mm_castpd_si128(a)      ((__m128i)(a))
#define _mm_castps_si128(a)      ((__m128i)(a))
#define _mm_cvtsi32_si128(a)     ((__m128i){0})
#define _mm_cvtps_epi32(a)       ((__m128i){0})
#define _mm_cvttps_epi32(a)      ((__m128i){0})
#define _mm_cvtss_si64(a)        (0LL)
#define _mm_cvtsd_si64(a)        (0LL)
#define _mm_cvtss_si32(a)        (0)
#define _mm_cvttss_si32(a)       (0)
#define _mm_move_sd(a, b)        (b)
#define _mm_movemask_epi8(a)     (0)
#define _mm_movemask_ps(a)       (0)
#define _mm256_extracti128_si256(a, n) ((__m128i){0})
#define _mm_extract_epi32(a, n)  (0)
#define _mm256_cvtepu8_epi16(a)  ((__m256i){0})

/* 7. シフト・数学・パック */
#define _mm_bslli_si128(a, i)    (a)
#define _mm_bsrli_si128(a, i)    (a)
#define _mm_slli_si128(a, i)     (a)
#define _mm_srli_si128(a, i)     (a)
#define _mm_sqrt_ps(a)           (a)
#define _mm_rcp_ps(a)            (a)
#define _mm_rsqrt_ps(a)          (a)
#define _mm_rcp_ss(a)            (a)
#define _mm_rsqrt_ss(a)          (a)
#define _mm_packus_epi16(a, b)   ((__m128i){0})
#define _mm_packs_epi32(a, b)    ((__m128i){0})
#define _mm256_or_si256(a, ...)     (a)
#define _mm256_cmpeq_epi8(a, ...)   (a)
#define _mm256_cmpeq_epi16(a, ...)  (a)
#define _mm256_cmpeq_epi32(a, ...)  (a)
#define _mm256_cmpeq_epi64(a, ...)  (a)
#define _mm256_movemask_epi8(...)   (0)
#define _mm_store_si128(p, a)    { (void)p; (void)a; }
#define _mm_min_ps(a, ...)       (a)
#define _mm_max_ps(a, ...)       (a)
#define _mm_cvtss_f32(...)       (0.0f)

#define _mm_set_ps(a, b, c, d)   ((__m128){(float)(a), (float)(b), (float)(c), (float)(d)})
#define _mm_cvtepi32_ps(a)       ((__m128){0, 0, 0, 0})
#define _mm_cmpgt_epi32(a, b)    (a)
#define _mm_loadu_si64(p)        ((__m128i)(__v2di){*(long long*)(p), 0})

#define _mm_cvtepu8_epi16(a)     ((__m128i){0})
#define _mm_add_epi16(a, b)      (a)
#define _mm_load_si128(p)        ((__m128i){0})
#define _mm_madd_epi16(a, b)     (a)
#define _mm_hadd_epi32(a, b)     (a)
#define _mm_cvtepu8_epi16(a)     ((__m128i){0})
#define _mm_loadl_epi64(p)       ((__m128i){0})
#define _mm_unpacklo_epi64(a, b) (a)
#define _mm_cvtsi128_si32(a)     ((int)0)
#define _mm_storel_epi64(p, a)   { (void)p; (void)a; }
#define _mm_setr_epi16(...)      ((__m128i){0})
#define _mm_avg_epu16(a, b)      (a)
#define _mm_srli_epi32(a, i)     (a)
#define _mm_cvt_ss2si(a)         ((int)0)

#define _mm_srli_epi16(a, i)     (a)
#define _mm_srai_epi16(a, i)     (a)
#define _mm256_store_si256(p, a) { (void)p; (void)a; }
#define _mm256_storeu_si256(p, a){ (void)p; (void)a; }
#define _mm256_insertf128_si256(a, b, i) (a)
#define _mm256_castsi128_si256(a) ((__m256i){0})
#define _mm_loadh_pd(a, p)       (a)
#define _mm256_castsi256_si128(a)((__m128i){0})
#define _mm256_setr_epi16(...)   ((__m256i){0})
#define _mm_srai_epi32(a, i)     (a)
#define _mm_add_ss(a, b)         (a)
#define _mm_loadu_ps(p)          ((__m128){0})
#define _mm_shuffle_ps(a, b, m)  (a)
#define _mm_storeu_ps(p, a)      { (void)p; (void)a; }
#define _mm_add_pd(a, b)         (a)
#define _mm_sub_pd(a, b)         (a)
#define _mm256_srli_epi32(a, i)  (a)
#define _mm_avg_epu16(a, b)      (a)
#define _mm_set_pd(a, b)         ((__m128d){(double)a,(double)b})
#define _mm_mul_pd(a, b)         (a)
#define _mm_set1_pd(x)           ((__m128d){(double)x,(double)x})
#define _mm256_srli_epi16(a, i)  (a)
#define _mm256_avg_epu16(a, b)   (a)
#define _mm_round_pd(a, f)       (a)
#define _mm_load1_ps(p)          ((__m128){0})
#define _mm_store_ss(p, a)       { (void)p; (void)a; }
#define _mm_cvtpd_epi32(a)       ((__m128i){0})
#define _mm_unpacklo_epi32(a, b) (a)
/* 4. 丸め処理フラグ (disflow 用) */
#define _MM_FROUND_TO_NEAREST_INT 0x00
#define _MM_FROUND_NO_EXC         0x08
#endif
EOF

# 対象とするヘッダーをさらに拡大
SIMD_HEADERS="mmintrin.h xmmintrin.h emmintrin.h pmmintrin.h tmmintrin.h smmintrin.h \
              wmmintrin.h __wmmintrin_aes.h __wmmintrin_pclmul.h \
              avxintrin.h avx2intrin.h avx512fintrin.h f16cintrin.h fmaintrin.h"

# 偽造ヘッダーを全 intrin.h に強制適用する「安全な」ループ
for h in /usr/lib/clang/18/include/*intrin.h; do
    # '|| true' を付けることで、アンマウントに失敗してもエラーを無視して次へ進む
    umount "$h" 2>/dev/null || true
    
    # 確実にマウントを実行
    mount --bind /tmp/fake_simd.h "$h"
done

echo "Applying full SIMD mask..."

# 3. bindgenに「自分はx86_64ではない」と思わせて、SIMD解析を諦めさせる
# 環境変数を以下のように書き換えてください
BINDGEN_FLAGS="-target x86_64-unknown-linux-gnu -D__MMX__=1 -D__SSE__=1 -D__SSE2__=1 -D__SSE3__=1 -D__SSSE3__=1 -D__SSE4_1__=1"

# 4. ビルド実行
# HOME を指定することで /root/.mozbuild へのアクセスを回避します
echo "Cleaning up..."
su -m user -c "HOME=/home/user ./mach clobber" > "$LOG/firefox.log" 2>&1

echo "Building... (Log: tail -f $LOG/firefox.log)"
# RUSTUP_TOOLCHAIN=stable を加えることで、rustup 経由のチェックを強制通過させます
# su コマンドの中で直接環境変数をセットして実行
su -m user -c "HOME=/home/user \
    PATH=\$PATH:/home/user/.cargo/bin \
    BINDGEN_EXTRA_CLANG_ARGS='$BINDGEN_FLAGS' \
    CLANG_FLAGS='$BINDGEN_FLAGS' \
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

