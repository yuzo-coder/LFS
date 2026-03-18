#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/sources
LOG=$ROOT/logs

# ディレクトリ準備
mkdir -p "$LOG"
mkdir -p "$SRC"
cd "$SRC"

# --- 共通設定 ---
if ! grep -q "PKG_CONFIG_PATH" /etc/profile; then
cat >> /etc/profile << "EOF"
# pkg-config の検索パスを追加
PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib64/pkgconfig:/usr/local/lib/pkgconfig
export PKG_CONFIG_PATH
EOF
fi

# --- 1. libtasn1 (p11-kitの依存) ---
echo "===== Building libtasn1 ====="
# ソースがない場合はダウンロード
[ -f libtasn1-4.19.0.tar.gz ] || wget https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz --no-check-certificate

rm -rf libtasn1-4.19.0
tar xf libtasn1-4.19.0.tar.gz
cd libtasn1-4.19.0

./configure --prefix=/usr --disable-static > "$LOG/libtasn1.log" 2>&1
make -j"$JOBS" >> "$LOG/libtasn1.log" 2>&1
make install >> "$LOG/libtasn1.log" 2>&1

cd "$SRC"
rm -rf libtasn1-4.19.0

# --- 2. p11-kit ---
echo "===== Building p11-kit ====="
[ -f p11-kit-0.25.5.tar.xz ] || wget https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz --no-check-certificate

rm -rf p11-kit-0.25.5
tar xf p11-kit-0.25.5.tar.xz
cd p11-kit-0.25.5

mkdir build && cd build
meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -Dtrust_module=enabled \
    -Dtrust_paths=/etc/pki/anchors \
    > "$LOG/p11-kit.log" 2>&1

ninja >> "$LOG/p11-kit.log" 2>&1
ninja install >> "$LOG/p11-kit.log" 2>&1
ldconfig

cd "$SRC"
rm -rf p11-kit-0.25.5

# --- 3. make-ca ---
echo "===== Installing make-ca and Certificates ====="
[ -f make-ca-1.15.tar.gz ] || wget https://github.com/lfs-book/make-ca/archive/v1.15/make-ca-1.15.tar.gz --no-check-certificate

rm -rf make-ca-1.15
tar xf make-ca-1.15.tar.gz
cd make-ca-1.15

make install >> "$LOG/make-ca.log" 2>&1

# Mozillaの証明書データ取得と配置
wget https://hg.mozilla.org/releases/mozilla-release/raw-file/default/security/nss/lib/ckfw/builtins/certdata.txt --no-check-certificate
mkdir -p /etc/pki/anchors
cp certdata.txt /etc/pki/anchors/

# 証明書のハッシュリンク再生成
/usr/sbin/make-ca -r >> "$LOG/make-ca.log" 2>&1

cd "$SRC"
rm -rf make-ca-1.15

# --- 4. wget (SSL対応版として再ビルドが必要な場合を想定) ---
echo "===== Building wget ====="
[ -f wget-1.25.0.tar.gz ] || wget https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz --no-check-certificate

rm -rf wget-1.25.0
tar xf wget-1.25.0.tar.gz
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

# --- 5. OpenSSH ---
echo "===== Building OpenSSH ====="
getent group sshd >/dev/null || groupadd -g 50 sshd
getent passwd sshd >/dev/null || useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
install -v -m700 -d /var/lib/sshd

[ -f openssh-10.2p1.tar.gz ] || wget https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.2p1.tar.gz --no-check-certificate

rm -rf openssh-10.2p1
tar xf openssh-10.2p1.tar.gz
cd openssh-10.2p1

./configure \
    --prefix=/usr \
    --sysconfdir=/etc/ssh \
    --with-privsep-path=/var/lib/sshd \
    > "$LOG/openssh.log" 2>&1

make -j"$JOBS" >> "$LOG/openssh.log" 2>&1
make install >> "$LOG/openssh.log" 2>&1

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A >> "$LOG/openssh.log" 2>&1
fi

cd "$SRC"
rm -rf openssh-10.2p1

# --- 6. Configuration (Systemd & Config) ---
echo "===== Final Configuration ====="
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

cat > /etc/ssh/sshd_config << "EOF"
Port 22
PasswordAuthentication yes
PermitRootLogin yes
Subsystem sftp internal-sftp
EOF

systemctl daemon-reload
systemctl restart sshd || true
systemctl enable sshd || true

echo "===== ALL PHASES COMPLETE ====="
