#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   19   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
fmt
spdlog
graphviz
# btop
yazi
greetd
gtkgreet

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# greetd login
if ! id "greeter" &>/dev/null; then
    # 1. ホームディレクトリを /var/lib/greetd に指定してユーザー作成 (-d, -m)
    #    システムアカウント (-r) として作成し、ログインシェルは不要 (-s)
    useradd -r -M -d /var/lib/greetd -s /bin/false -G video greeter
    
    # 2. 必要なグループ（seat, video, input）を一括追加
    usermod -aG seat,video,input greeter
fi

mkdir -p /var/lib/greetd
chown -R greeter:greeter /var/lib/greetd
chmod 700 /var/lib/greetd

mkdir -p /etc/greetd

# greetd 設定
cat > /etc/greetd/config.toml <<EOF
[terminal]
# ログイン画面を表示するTTY（通常は1）
vt = 1
[default_session]
# 【超安全モード】Swayをそのままシンプルに呼び出します
command = "env WLR_NO_HARDWARE_CURSORS=1 sway --config /etc/greetd/sway.config"
# ログイン画面を動かす専用のシステムユーザー（greeterまたはgreetd）
user = "greeter"
EOF

# gtkgreet用の専用Sway設定 (ログイン画面用)
cat > /etc/greetd/sway.config <<EOF
exec "dbus-update-activation-environment --all"
#exec "gtkgreet -l -c /usr/bin/sway; swaymsg exit"
exec "gtkgreet -l -s /etc/greetd/style.css -c 'dbus-run-session env WLR_NO_HARDWARE_CURSORS=1 /usr/bin/sway'; swaymsg exit"
include /etc/sway/config.d/*
EOF

cat > /etc/greetd/style.css <<EOF
window {
background-color: #ffffff;
    color: #393f4c;
    font-family: "Sans", sans-serif;
    font-size: 16px;

}

/* 中央のログインフォームを囲むボックス */
box#container {
    background-color: #2a2a35;
    padding: 35px;
    border-radius: 10px;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.5);
}

/* ユーザー名・パスワードの入力ボックス */
entry {
    background-color: #ffffff;
    color: #000000;
    border: 2px solid #5a5a75;
    border-radius: 6px;
    padding: 8px 12px;
    margin: 6px 0;
}

/* 入力欄を選択したとき（枠線をアクティブな青に） */
entry:focus {
    border-color: #7289da;
}

/* ログインボタンの装飾 */
button {
    background-color: #4e5d94;
    color: white;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: bold;
}
button:hover {
    background-color: #677bc4;
}
EOF

ldconfig


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   19   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
