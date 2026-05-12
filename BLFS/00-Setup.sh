#!/bin/bash
set -euo pipefail

source ./functions.sh

cd "$SRC"

# 1. ユーザー権限の設定
echo "Step 1: Setting up user groups..."
# 'user' というユーザーが存在することを確認してから実行
if id "user" &>/dev/null; then
    for grp in video input render seat; do
        groupadd -f -r "$grp"
        usermod -aG "$grp" user
    done
else
    echo "Warning: User 'user' not found. skipping group assignment."
fi

# Japansene Keyboard Keymap
localectl set-keymap jp106

# mkdir -p /lib/firmware
# touch /lib/firmware/regulatory.db

mkdir -p /var/lib/alsa

# /etc/profile
cat >> /etc/profile << "EOF"
# loadkeys jp106
ulimit -n 65536

PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-}:/usr/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
export PATH=/usr/local/bin:$PATH:/root/.cargo/bin
export PKG_CONFIG_PATH
export MAKEFLAGS="-j$(nproc)"
export LANG=en_US.UTF-8

# /etc/profile.d/*.sh ファイルを読み込む設定
if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r "$i" ]; then
      . "$i"
    fi
  done
  unset i
fi
EOF

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Timezone Tokyo
ln -sfv /usr/share/zoneinfo/Asia/Tokyo /etc/localtime


# UDEV Not Show
cat >> /etc/udev/udev.conf << 'EOF'
udev_log="error"
EOF

cat > /etc/profile.d/bash_colors.sh << "EOF"
# --- 1. dircolors Setting (LS COLOR) ---
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

alias vi='vi -u NONE'
alias vim='vim -u NONE'

# --- 3. プロンプト (PS1) の色分け設定 ---
# 色コードの定義（BLUE を CYAN '36' に変えると見やすくなります）
# BLUEは見えにくいので嫌や
RED='\[\e[1;31m\]'
GREEN='\[\e[1;32m\]'
CYAN='\[\e[1;36m\]'  # 見えにくい BLUE の代わりに
RESET='\[\e[0m\]'

if [ $(id -u) -eq 0 ]; then
    PS1="${RED}\u${RESET}@\h:${CYAN}\w${RESET}# "
else
    PS1="${GREEN}\u${RESET}@\h:${CYAN}\w${RESET}$ "
fi

# 256color は vi などの色を誘発するので、
# 色付きプロンプトだけが目的なら標準の xterm でも十分です
export TERM=xterm-256color

# ディレクトリの色を「太字のシアン」に変更する設定
export LS_COLORS=$LS_COLORS:'di=01;36:'
EOF

# 実行権限の付与
chmod +x /etc/profile.d/bash_colors.sh

# 共通の dircolors ファイルがなければ作成しておく
if [ ! -f /etc/dircolors ]; then
    dircolors -p > /etc/dircolors
fi
source /etc/profile
echo "===== Bash Color Setup Complete ====="


# ---  systemd-networkd 設定 (追加分) ---
echo "===== Configuring Network (systemd-networkd) ====="

# 物理インターフェースの有効化
# ループバック(lo)以外の、物理または仮想インターフェース名を取得
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e(n|t)' | head -n 1)

mkdir -p /etc/systemd/network

for IFACE in $INTERFACES; do
    echo "Found interface: $IFACE. Creating configuration..."
    
    cat > "/etc/systemd/network/10-${IFACE}.network" << EOF
[Match]
Name=en*

[Network]
DHCP=yes
DNS=8.8.8.8
EOF

    # インターフェースをUPにする
    ip link set "$IFACE" up
done



#  systemd-resolved の設定 (DNS解決に必要)
# DNS=8.8.8.8 を反映させるため、resolved も有効化し、/etc/resolv.conf をリンクします
systemctl enable systemd-resolved
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

#  サービスの有効化と開始
systemctl enable systemd-networkd
systemctl restart systemd-networkd

# グループ作成
for grp in pulse pulse-access audio rtkit; do
    groupadd -f "$grp"
done

# システムユーザー作成
if ! getent passwd pulse >/dev/null; then
    useradd -c "PulseAudio Revision" -d /var/run/pulse -u 52 -g pulse -s /bin/false pulse
fi

if ! getent passwd rtkit >/dev/null; then
    useradd -c "RealtimeKit Daemon User" -d /var/lib/rtkit -u 133 -g rtkit -s /bin/false rtkit
fi

# 一般ユーザーの権限付与
if getent passwd user >/dev/null; then
    usermod -aG audio,pulse,pulse-access,rtkit user
fi

cat > /etc/systemd/journald.conf << 'EOF'
Storage=volatile
EOF


scripts=(

wget-1
libtasn1
p11-kit
make-ca
wget-2
curl
git
which
sudo
openssh-1

)


for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 00 COMPLETE ====="
