#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   19   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
fmt
spdlog
graphviz
# btop
yazi
greetd
gtkgreet

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done





if ! id "greeter" &>/dev/null; then
    useradd -M -G video greeter
    usermod -aG seat,video,input greeter
fi

mkdir -p /etc/greetd

cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1
[default_session]
command = "gtkgreet -l -c sway"
user = "greeter"
EOF

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   19   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
