#!/bin/bash
set -euo pipefail

source ./functions.sh


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                      START                          =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

TAR_NAME="firefox-128.1.0esr.source.tar.xz"
NAME="firefox-128.1.0"


echo "===== Preparing $NAME ====="
cd "$SRC"

# --- 7. インストール（root権限） ---
echo "Installing Firefox..."

export LD_LIBRARY_PATH=/opt/python311/lib:${LD_LIBRARY_PATH:-}

export PYTHON=/opt/python311/bin/python3.11

export PATH=/opt/python311/bin:$PATH

# $PYTHON ./mach install >> "$LOG/firefox.log" 2>&1

# インストール先ディレクトリの作成

rm -rf /usr/lib/firefox

mkdir -pv /usr/lib/firefox

if [ -d "/tmp/firefox-obj/dist/firefox" ]; then
    echo "Copying complete firefox distribution..."
    cp -Ruv /tmp/firefox-obj/dist/firefox/* /usr/lib/firefox/
else
    echo "Fallback: Copying from dist/bin (check if omni.ja exists!)"
    cp -Ruv /tmp/firefox-obj/dist/bin/* /usr/lib/firefox/
fi

# --- 8. 最適化（2GBのlibxul.soを軽量化） ---
echo "Stripping debug symbols to speed up loading..."
strip --strip-unneeded /usr/lib/firefox/libxul.so
strip --strip-unneeded /usr/lib/firefox/firefox
strip --strip-unneeded /usr/lib/firefox/libmoz*.so


# 上記の su コマンドが成功したか（戻り値 0 か）を厳密にチェック
if [ $? -ne 0 ]; then
    echo "ERROR: 'make package' failed!"
    exit 1
fi

# 2. インストール先ディレクトリの事前準備（root権限）
echo "===> Installing Firefox to /usr/lib/firefox/..."
mkdir -p /usr/lib/firefox

# 3. 「-L」をつけて、リンク先の実体をコピーする
# コピー元（/tmp/firefox-obj/dist/firefox/*）が本当に存在するか確認
if [ -d "/tmp/firefox-obj/dist/firefox" ]; then
    cp -RLuv /tmp/firefox-obj/dist/firefox/* /usr/lib/firefox/
else
    echo "ERROR: Build artifact directory not found! Check if 'make package' really succeeded."
    exit 1
fi

# 4. 共有ライブラリのパス通しとキャッシュ更新
echo "/usr/lib/firefox" > /etc/ld.so.conf.d/firefox.conf
ldconfig

echo "===> Firefox installation completed successfully!"

echo "===== /usr/bin/start-firefox ====="
cat << 'EOF' > /usr/bin/start-firefox
#!/bin/bash

# fcitx5がなければ起動
pgrep -x "/usr/bin/fcitx5" > /dev/null || /usr/bin/fcitx5 -d

export MOZ_ENABLE_WAYLAND=1

/usr/lib/firefox/firefox > /tmp/firefox.log 2>&1 &
EOF

chmod +x /usr/bin/start-firefox

echo "===== COMPLETE ====="
