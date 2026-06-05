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
vt = 1
[default_session]
command = "/usr/bin/sway --config /etc/greetd/sway.config"
user = "greeter"
EOF

# gtkgreet用の専用Sway設定 (ログイン画面用)
cat > /etc/greetd/sway.config <<EOF
exec "dbus-update-activation-environment --all"

exec "gtkgreet -l -c /usr/bin/sway; swaymsg exit"

include /etc/sway/config.d/*
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
