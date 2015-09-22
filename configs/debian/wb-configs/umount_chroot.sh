#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

[[ $EUID == 0 ]] || {
	exec sudo -E unshare -m $0 "$@"
}
[[ -L $DIR/dev/ptmx ]] || umount $DIR/dev/ptmx
umount $DIR/dev/pts
umount $DIR/proc
umount $DIR/sys
