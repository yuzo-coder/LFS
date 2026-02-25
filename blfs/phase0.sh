#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/source
LOG=$ROOT/logs

mkdir -p "$LOG"
cd "$SRC"

echo "===== Building wget ====="

rm -rf wget-1.25.0
tar xzvf wget-1.25.0.tar.gz
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


echo "===== Building OpenSSH ====="

# sshd group (存在しなければ作成)
if ! getent group sshd >/dev/null; then
    groupadd -g 50 sshd
fi

# sshd user (存在しなければ作成)
if ! id sshd >/dev/null 2>&1; then
    useradd \
        -c 'sshd PrivSep' \
        -d /var/lib/sshd \
        -g sshd \
        -s /bin/false \
        -u 50 \
        sshd
fi

install -v -m700 -d /var/lib/sshd

rm -rf openssh-10.2p1
tar xzvf openssh-10.2p1.tar.gz
cd openssh-10.2p1

./configure \
    --prefix=/usr \
    --sysconfdir=/etc/ssh \
    --with-privsep-path=/var/lib/sshd \
    > "$LOG/openssh.log" 2>&1

make -j"$JOBS" >> "$LOG/openssh.log" 2>&1
make install >> "$LOG/openssh.log" 2>&1

cd "$SRC"
rm -rf openssh-10.2p1

echo "===== OpenSSH build complete ====="


echo "===== Installing systemd unit ====="

install -v -m644 /dev/null /usr/lib/systemd/system/sshd.service

cat > /usr/lib/systemd/system/sshd.service << "EOF"
[Unit]
Description=OpenSSH Daemon
After=network.target

[Service]
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sshd

echo "===== PHASE0 COMPLETE ====="
