#!/bin/bash
# =================================================================
# LFS Build Verification Script
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
 
echo "===== Starting LFS Environment Verification ====="
 
# 判定関数
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "[  ${GREEN}OK${NC}  ] $1"
    else
        echo -e "[ ${RED}FAIL${NC} ] $1"
        return 1
    fi
}
 
# 1. ネットワークと名前解決の検証
echo -e "\n--- 1. Networking & DNS ---"
traceroute -m 10 8.8.8.8 
check_status "Tracert to IP (8.8.8.8)"
 
systemctl is-active --quiet systemd-networkd
check_status "Service: systemd-networkd is running"
 
systemctl is-active --quiet systemd-resolved
check_status "Service: systemd-resolved is running"
 
# 2. SSL/TLS 証明書の検証
echo -e "\n--- 2. SSL/TLS Certificates ---"
[ -f /etc/pki/tls/certs/ca-bundle.crt ]
check_status "CA Bundle exists"
 
# wget を使った実際のSSL通信テスト
wget --spider https://www.google.com >/dev/null 2>&1
check_status "Wget HTTPS connectivity (SSL Check)"
 
# 3. ビルド済みバイナリの検証
echo -e "\n--- 3. Installed Binaries & Versions ---"
commands=("wget" "curl" "git" "which" "sudo" "sshd")
for cmd in "${commands[@]}"; do
    if command -v $cmd >/dev/null 2>&1; then
        version=$($cmd --version 2>&1 | head -n 1)
        echo -e "[  ${GREEN}OK${NC}  ] $cmd found: $version"
    else
        echo -e "[ ${RED}FAIL${NC} ] $cmd NOT found"
    fi
done
 
# 4. SSH サービスの検証
echo -e "\n--- 4. SSH Service ---"
systemctl is-active --quiet sshd
check_status "Service: sshd is running"
 
ss -tulpn | grep -q ":22"
check_status "Listening on Port 22"
 
# 5. Sudo 権限の検証
echo -e "\n--- 5. Sudo Configuration ---"
[ -f /etc/sudoers.d/user ]
check_status "Sudoers file for 'user' exists"
 
# 6. 環境設定の検証
echo -e "\n--- 6. Environment & Localization ---"
date | grep -q "JST"
check_status "Timezone is set to Tokyo (JST)"
 
[ -x /etc/profile.d/bash_colors.sh ]
check_status "Bash colors script is executable"
 
echo -e "\n===== Verification Complete ====="
