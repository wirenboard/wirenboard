#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

umount $DIR/proc
umount $DIR/dev/pts
umount $DIR/dev
umount $DIR/sys
