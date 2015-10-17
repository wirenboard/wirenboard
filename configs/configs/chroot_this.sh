#!/bin/bash
set -x
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

[[ -n "$__unshared" ]] || {
	[[ $EUID == 0 ]] || {
		exec sudo -E "$0" "$@"
	}

	# Jump into separate namespace
	export __unshared=1
	exec unshare -umipf "$0" "$@"
}

mkdir -p $DIR/proc
mkdir -p $DIR/sys
mkdir -p $DIR/dev/pts

mount -t proc none $DIR/proc
mount -t sysfs none $DIR/sys
#mount --bind /dev $DIR/dev
mount -t devpts devpts $DIR/dev/pts -o "gid=5,mode=620,ptmxmode=666,newinstance"
[[ -L $DIR/dev/ptmx ]] || mount --bind $DIR/dev/pts/ptmx $DIR/dev/ptmx

cleanup_mounts() {
	umount "$DIR/proc"
	umount "$DIR/sys"
    umount -R "$DIR/dev/pts"
	#~ umount -R "$DIR/dev"
}
trap cleanup_mounts EXIT

chroot $DIR "$@"
