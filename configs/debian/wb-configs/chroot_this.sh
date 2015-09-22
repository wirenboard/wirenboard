#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

[[ $EUID == 0 ]] || {
	exec sudo -E unshare -m $0 "$@"
}

mount --bind /proc $DIR/proc
mount --bind /sys $DIR/sys
mount --bind /dev $DIR/dev
mount -t devpts devpts $DIR/dev/pts -o "gid=5,mode=620,ptmxmode=666,newinstance"
[[ -L $DIR/dev/ptmx ]] || mount -o bind $DIR/dev/pts/ptmx $DIR/dev/ptmx

chroot $DIR "$@"
