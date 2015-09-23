#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

mount -o bind /proc $DIR/proc
mount --rbind /dev $DIR/dev
mount -o bind /sys $DIR/sys

chroot $DIR "$@"
