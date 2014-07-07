#!/bin/bash
sudo umount /dev/mmcblk0p1
sudo umount /dev/mmcblk0p2

sudo dd if=$1 of=/dev/mmcblk0 bs=4M conv=fdatasync
sync
sync
sudo parted /dev/mmcblk0 -s "resizepart 2 -0"
