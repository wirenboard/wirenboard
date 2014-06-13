#!/bin/bash
echo "USAGE: $0 /dev/mmcblk0p2"

if [ "x$1" = "x" ]; then
    echo "please specify device";
    exit 1;
fi
    
sudo mkfs.ext4 $1 -E stride=2,stripe-width=1024 -b 4096 -L rootfs 131072