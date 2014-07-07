#!/bin/bash
if [ "x$1" = "x" ]; then
    echo "please provide the image location"
    exit 1;
fi

sudo umount /dev/mmcblk0p1
sudo umount /dev/mmcblk0p2

sudo dd if=$1 of=/dev/mmcblk0 bs=4M conv=fdatasync
sync
sync
sudo parted /dev/mmcblk0 -s "resizepart 2 -0"
