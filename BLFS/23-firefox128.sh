#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
#    "libdrm"
#    "llvm"
#    "python311"
    "firefox128"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


# /usr/bin/firefox
cat >> /usr/bin/firefox << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH=/opt/python311/lib:${LD_LIBRARY_PATH:-}
exec /usr/lib/firefox-128.0/firefox "$@"
EOF

echo "===== Firefox-128 Complete ====="
