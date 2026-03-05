#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/sources
LOG=$ROOT/logs

mkdir -p "$LOG"
cd "$SRC"

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

make -j"$JOBS" >> "$LOG/wget.log" 2>&1
make install >> "$LOG/wget.log" 2>&1

cd "$SRC"
rm -rf wget-1.25.0
echo "===== wget complete ====="

# --- OpenSSH ---
echo "===== Building OpenSSH ====="

# ID 50 が既に使用されていないか、より安全なチェック
getent group sshd >/dev/null || groupadd -g 50 sshd
getent passwd sshd >/dev/null || useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd

install -v -m700 -d /var/lib/sshd

rm -rf openssh-10.2p1
tar xf openssh-10.2p1.tar.gz
cd openssh-10.2p1

./configure \
    --prefix=/usr \
    --sysconfdir=/etc/ssh \
    --with-privsep-path=/var/lib/sshd \
    --with-mdns \
    > "$LOG/openssh.log" 2>&1

make -j"$JOBS" >> "$LOG/openssh.log" 2>&1
make install >> "$LOG/openssh.log" 2>&1

# 【追加】ホストキーの生成 (これがないと起動しません)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A >> "$LOG/openssh.log" 2>&1
fi

cd "$SRC"
rm -rf openssh-10.2p1
echo "===== OpenSSH build complete ====="

# --- Systemd Unit ---
echo "===== Installing systemd unit ====="

# /usr/lib/systemd/system/ ディレクトリが存在することを確認
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

# 反映と有効化
systemctl daemon-reload
# 既に有効化されている場合のエラーを避けるため
systemctl enable sshd || true

echo "===== PHASE0 COMPLETE ====="

