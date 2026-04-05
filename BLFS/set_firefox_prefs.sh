#!/bin/bash

# 1. Firefoxのプロファイルディレクトリを取得
# 通常、.mozilla/firefox/ 内の「xxxx.default-release」のような名前のディレクトリです
PROFILE_DIR=$(find /home/user/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default-release" | head -n 1)

# プロファイルが見つからない場合のフォールバック（初回起動前など）
if [ -z "$PROFILE_DIR" ]; then
    PROFILE_DIR=$(find /home/user/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default" | head -n 1)
fi

if [ -z "$PROFILE_DIR" ]; then
    echo "エラー: Firefoxのプロファイルが見つかりません。一度Firefoxを起動してください。"
    exit 1
fi

USER_JS="$PROFILE_DIR/user.js"

cat << 'EOF' >> "$USER_JS"
user_pref("media.rdd-process.enabled", false);
user_pref("media.utility-process.enabled", false);
user_pref("layers.acceleration.disabled", true);
user_pref("media.hardware-video-decoding.enabled", false);
user_pref("security.sandbox.content.level", 0);
user_pref("gfx.webrender.force-disabled", true);
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.canvas.acceleration", false);
user_pref("media.hardware-video-decoding.force-enabled", false);
user_pref("webgl.disabled", true); // VirGLの不安定なWebGLを一旦捨てる

// GPUプロセスとハードウェア加速を完全に無効化
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.all", false);
user_pref("gfx.webrender.software", true); // ソフトウェアレンダリングを強制
user_pref("gfx.canvas.acceleration", false);
// WebGLを無効化（ログにあるサニタイズエラーを回避）
user_pref("webgl.disabled", true);
user_pref("webgl.enable-webgl2", false);
// ビデオデコードもソフトウェアで行う
user_pref("media.hardware-video-decoding.enabled", false);
user_pref("media.gpu-process-decoder", false);
// サンドボックスの無効化（LFSでのライブラリ競合を回避）
user_pref("security.sandbox.content.level", 0);

// 1. クラッシュしているデコード専用プロセスを完全に殺す
user_pref("media.utility-process.enabled", false);
user_pref("media.rdd-process.enabled", false);

// 2. グラフィックスの「健全性チェック」による自爆を防ぐ
user_pref("gfx.sandbox.gpu.level", 0);
user_pref("media.gpu-process-decoder", false);

// 3. VirGLエラー（Couldn't sanitize）の元を断つ
user_pref("webgl.disabled", true);
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.software", true);

// 4. FFmpegをメインプロセスで直接駆動させる
user_pref("media.ffmpeg.enabled", true);
EOF
echo "設定が完了しました。Firefoxを再起動してください。"
