#!/bin/bash
if [ "x$1" = "x" ]; then
    echo "please provide the image location"
    exit 1;
fi
if [ "x$2" = "x" ]; then
    echo "please provide sdcard device prefix (example: /dev/sdX)"
    exit 1;
fi

DEV=$2

sudo umount ${DEV}2
sudo umount ${DEV}1

sudo dd if=$1 of=${DEV} bs=4M conv=fdatasync
sync
sync
#sudo parted ${DEV} -s "resizepart 2 -0"
