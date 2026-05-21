#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   05   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
pam

openssh-2

shadow
popt
keyutils
systemd
seatd
shared-mime-info

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# PAM設定の最小構成（これがないとログインできなくなります）
if [ ! -f /etc/pam.d/other ]; then
    mkdir -p /etc/pam.d
    cat > /etc/pam.d/other << "EOF"
auth     required       pam_unix.so
account  required       pam_unix.so
password required       pam_unix.so
session  required       pam_unix.so
EOF
fi

# system-session: セッション開始時に systemd-logind をフックする
cat > /etc/pam.d/system-session << "EOF"
session    required    pam_loginuid.so
session    required    pam_limits.so
session    required    pam_unix.so
session    required    pam_systemd.so
EOF

# system-auth: 基本認証（これがないとlogin自体ができなくなる恐れあり）
cat > /etc/pam.d/system-auth << "EOF"
auth       required    pam_unix.so
account    required    pam_unix.so
password   required    pam_unix.so
session    required    pam_unix.so
EOF

# login: 物理コンソールからのログイン用（最重要）
cat > /etc/pam.d/login << "EOF"
auth      requisite    pam_nologin.so
auth      include      system-auth
account   include      system-auth
password  include      system-auth
session   include      system-session
EOF

# sshd: リモートログイン用
cat > /etc/pam.d/sshd << "EOF"
auth      include      system-auth
account   include      system-auth
password  include      system-auth
session   include      system-session
EOF

cat > /etc/pam.d/su << "EOF"
#%PAM-1.0
auth            sufficient      pam_rootok.so
auth            include         system-auth
account         include         system-auth
session         include         system-auth
session         include         system-session
EOF

cat > /etc/pam.d/system-auth << "EOF"
#%PAM-1.0
auth            required        pam_unix.so
account         required        pam_unix.so
password        required        pam_unix.so
session         required        pam_unix.so
EOF

mkdir -p /etc/systemd/system/user@.service.d
cat > /etc/systemd/system/user@.service.d/10-environment.conf << "EOF"
[Service]
Environment="XDG_RUNTIME_DIR=/run/user/%i"
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%i/bus"
EOF

systemctl daemon-reload

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   05   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
