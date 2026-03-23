#!/bin/bash
# =================================================================
# LFS Session & Login Stack Verification (PAM/systemd/D-Bus/seatd)
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}===== Starting Session Stack Verification =====${NC}"

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "[  ${GREEN}OK${NC}  ] $1"
    else
        echo -e "[ ${RED}FAIL${NC} ] $1"
        return 1
    fi
}

# 1. ライブラリとバイナリの生存確認
echo -e "\n--- 1. Binaries & Shared Libraries ---"
[ -f /usr/lib/libpam.so ] && [ -f /usr/lib/libglib-2.0.so ]
check_status "Critical Libraries (PAM, GLib) found in /usr/lib"

command -v busctl >/dev/null || command -v dbus-send >/dev/null
check_status "D-Bus tools found"

command -v seatd >/dev/null
check_status "seatd binary found"

# 2. PAM 設定の健全性チェック (最重要)
echo -e "\n--- 2. PAM Configuration Integrity ---"
# ファイルが存在するか
[ -f /etc/pam.d/login ] && [ -f /etc/pam.d/system-session ]
check_status "PAM login/session files exist"

# 循環参照や記述ミスがないか（簡易チェック）
grep -q "pam_systemd.so" /etc/pam.d/system-session
check_status "pam_systemd.so is registered in session"

# 3. Systemd サービスの状態
echo -e "\n--- 3. Systemd Services Status ---"
if systemctl is-system-running --quiet || [ -d /run/systemd/system ]; then
    systemctl is-active --quiet dbus
    check_status "Service: D-Bus is running"

    systemctl is-active --quiet systemd-logind
    check_status "Service: systemd-logind is running"

    systemctl is-active --quiet seatd
    check_status "Service: seatd is running"
else
    echo -e "[ ${YELLOW}SKIP${NC} ] Systemd services (Running in chroot?)"
fi

# 4. ユーザー権限とグループ
echo -e "\n--- 4. User Privileges & Groups ---"
if id "user" &>/dev/null; then
    groups user | grep -E "video|input|render|seat" >/dev/null
    check_status "User 'user' belongs to GUI groups (video, input, etc.)"
else
    echo -e "[ ${YELLOW}WARN${NC} ] User 'user' does not exist"
fi

# 5. D-Bus 通信テスト
echo -e "\n--- 5. D-Bus Communication Test ---"
if [ -S /run/dbus/system_bus_socket ]; then
    dbus-send --system --dest=org.freedesktop.DBus --type=method_call \
    --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1
    check_status "D-Bus System Bus is responding"
else
    echo -e "[ ${RED}FAIL${NC} ] D-Bus socket not found"
fi

# 6. 環境変数の検証
echo -e "\n--- 6. Runtime Environment ---"
[ -f /etc/profile.d/sway.sh ]
check_status "Sway environment script exists in profile.d"

# XDG_RUNTIME_DIR の所有権確認（ログイン中と仮定）
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    [ -d "$XDG_RUNTIME_DIR" ] && [ -O "$XDG_RUNTIME_DIR" ]
    check_status "XDG_RUNTIME_DIR is valid and owned by current user"
fi

echo -e "\n${YELLOW}===== Verification Complete =====${NC}"
echo "Tip: If PAM fails, you might be locked out of the console."
echo "Ensure you have a root shell or LiveCD ready just in case."
