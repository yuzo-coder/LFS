#Configuration file for scripts to run on host as root

PWD=`pwd`
LFS="$PWD/builddir"
MAKEFLAGS="-j`nproc`"
PARTITION="sdb1"

echo $LFS

export PWD LFS MAKEFLAGS
