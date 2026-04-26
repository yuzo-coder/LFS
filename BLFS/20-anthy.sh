#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "anthy"
    "fcitx5-anthy"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# プロファイル設定の書き込み
cat << 'EOF' > /home/user/.bash_profile
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
EOF

echo "===== All tasks completed successfully! ====="
echo "Please restart fcitx5 and add 'Anthy' from your config tool."
