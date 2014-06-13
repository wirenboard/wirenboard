#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

mount -o bind /proc $DIR/proc
mount -o bind /dev $DIR/dev
mount -o bind /dev/pts $DIR/dev/pts
mount -o bind /sys $DIR/sys

chroot $DIR