#!/bin/bash
set -euo pipefail

# Preferences
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
export MAKEFLAGS="-j$(nproc)"

mkdir -p "$SRC" "$LOG"

cd "$SRC"

# Japansene Keyboard Keymap
localectl set-keymap jp106

chown -v root:root /usr/sbin/shutdown /usr/sbin/reboot
chmod -v 4755 /usr/sbin/shutdown /usr/sbin/reboot

# /etc/profile
cat >> /etc/profile << "EOF"
loadkeys jp106
ulimit -n 65536

# PKG_CONFIG_PATH
# ${PKG_CONFIG_PATH:-}	
PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-}:/usr/lib64/pkgconfig:/usr/local/lib/pkgconfig
export PATH=$PATH:/usr/local/bin:/root/.cargo/bin
export PKG_CONFIG_PATH
export MAKEFLAGS="-j$(nproc)"
# export LANG=ja_JP.UTF-8
# export LC_ALL=ja_JP.UTF-8

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

# Timezone Tokyo
ln -sfv /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# UDEV Not Show
cat >> /etc/udev/udev.conf << 'EOF'
udev_log="err"
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
Name=${IFACE}

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

# --- 2. 共通関数 ---
download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

# --- wget ---
echo "===== Building wget ====="
rm -rf wget-1.25.0
tar xf wget-1.25.0.tar.gz  # zオプションはなくてもtarが自動判別します
cd wget-1.25.0

./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --with-ssl=openssl \
    > "$LOG/wget.log" 2>&1

make -j"$JOBS" 2>&1 | tee -a "$LOG/wget.log"
make install 2>&1 | tee -a "$LOG/wget.log"

cd "$SRC"
rm -rf wget-1.25.0
echo "===== wget complete ====="

# --- 3. SSL/証明書基盤 ---

# 3-1. libtasn1
echo "===== Building libtasn1 ====="
DIR=$(download_extract "https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz")
cd "$DIR"
./configure --prefix=/usr --disable-static > "$LOG/libtasn1.log" 2>&1
make -j"$JOBS" >> "$LOG/libtasn1.log" 2>&1
make install >> "$LOG/libtasn1.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# 3-2. p11-kit
echo "===== Building p11-kit ====="
DIR=$(download_extract "https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz")
cd "$DIR"
cd build
meson setup .. --prefix=/usr --buildtype=release -Dtrust_module=enabled -Dtrust_paths=/etc/pki/anchors > "$LOG/p11-kit.log" 2>&1
ninja >> "$LOG/p11-kit.log" 2>&1
ninja install >> "$LOG/p11-kit.log" 2>&1
ldconfig
cd "$SRC" && rm -rf "$DIR"

# 3-3. make-ca
echo "===== Installing make-ca and Certificates ====="
DIR=$(download_extract "https://github.com/lfs-book/make-ca/archive/v1.15/make-ca-1.15.tar.gz")
cd "$DIR"
make install >> "$LOG/make-ca.log" 2>&1
# Mozillaの最新証明書データ取得
wget https://hg.mozilla.org/releases/mozilla-release/raw-file/default/security/nss/lib/ckfw/builtins/certdata.txt --no-check-certificate
cp certdata.txt /etc/ssl/
/usr/sbin/make-ca -r >> "$LOG/make-ca.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# --- 4. ネットワーク & ダウンロードツール ---

# 4-1. wget (SSL対応再ビルド)
echo "===== Building wget (SSL support) ====="
tar xf wget-1.25.0.tar.gz
cd wget-1.25.0
./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl > "$LOG/wget.log" 2>&1
make -j"$JOBS" >> "$LOG/wget.log" 2>&1
make install >> "$LOG/wget.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# 4-2. curl
echo "===== Building curl ====="
DIR=$(download_extract "https://curl.se/download/curl-8.15.0.tar.xz")
cd "$DIR"
./configure --prefix=/usr \
            --with-openssl \
            --enable-threaded-resolver \
            --with-ca-path=/etc/ssl/certs \
            --without-libpsl > "$LOG/curl.log" 2>&1
make -j"$JOBS" >> "$LOG/curl.log" 2>&1
make install >> "$LOG/curl.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# 4-3. git
echo "===== Building git ====="
DIR=$(download_extract "https://www.kernel.org/pub/software/scm/git/git-2.50.1.tar.xz")
cd "$DIR"
./configure --prefix=/usr --with-curl --with-openssl --with-python=python3 --sysconfdir=/etc > "$LOG/git.log" 2>&1
make -j"$JOBS" >> "$LOG/git.log" 2>&1
make install >> "$LOG/git.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# --- 5. システム管理ツール ---

# 5-1. which
echo "===== Building which ====="
DIR=$(download_extract "https://ftp.gnu.org/gnu/which/which-2.23.tar.gz")
cd "$DIR"
./configure --prefix=/usr > "$LOG/which.log" 2>&1
make -j"$JOBS" >> "$LOG/which.log" 2>&1
make install >> "$LOG/which.log" 2>&1
cd "$SRC" && rm -rf "$DIR"

# 5-2. sudo
echo "===== Building sudo ====="
DIR=$(download_extract "https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz")
cd "$DIR"
./configure --prefix=/usr \
            --libexecdir=/usr/lib \
            --with-secure-path \
            --with-all-insults \
            --with-env-editor \
            --docdir=/usr/share/doc/sudo-1.9.16p1 \
            --with-passprompt="[sudo] password for %p: " \
	    CFLAGS="-g -O2 -Wno-error=incompatible-pointer-types" > "$LOG/sudo.log" 2>&1

make -j"$JOBS" >> "$LOG/sudo.log" 2>&1
make install >> "$LOG/sudo.log" 2>&1

# 権限設定
mkdir -p /etc/sudoers.d
[ -f /etc/sudoers.d/user ] || echo "user ALL=(ALL:ALL) ALL" > /etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
chmod 440 /etc/sudoers
cd "$SRC" && rm -rf "$DIR"

# --- 6. OpenSSH ---
echo "===== Building OpenSSH ====="
getent group sshd >/dev/null || groupadd -g 50 sshd
getent passwd sshd >/dev/null || useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
install -v -m700 -d /var/lib/sshd

DIR=$(download_extract "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.2p1.tar.gz")
cd "$DIR"
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-privsep-path=/var/lib/sshd > "$LOG/openssh.log" 2>&1
make -j"$JOBS" >> "$LOG/openssh.log" 2>&1
make install >> "$LOG/openssh.log" 2>&1

[ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A >> "$LOG/openssh.log" 2>&1

# Systemd Unit
mkdir -p /usr/lib/systemd/system
cat > /usr/lib/systemd/system/sshd.service << "EOF"
[Unit]
Description=OpenSSH Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# SSH Config (Root許可)
cat > /etc/ssh/sshd_config << "EOF"
Port 22
PasswordAuthentication yes
PermitRootLogin yes
Subsystem sftp internal-sftp
EOF

systemctl daemon-reload
systemctl restart sshd || true
systemctl enable sshd || true

echo "===== ALL PHASES COMPLETE: SSL & Base Tools Installed ====="
