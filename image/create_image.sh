#!/bin/bash
# need sudo apt-get install multipath-tools

echo "USAGE: $0 <path to rootfs> <img file>"
if [ $# -ne 2 ]
then
  exit 1
fi

IMGFILE="$2"
ROOTFS="$1"

# create image file
dd if=/dev/zero of=$IMGFILE bs=1M count=700
sudo ./create_partitions.sh  $IMGFILE

if [ -e /dev/mapper/loop0p1 ]; then
	echo "/dev/mapper/loop0p1 already exists"
	exit 2;
fi

if [ -e /dev/mapper/loop0p2 ]; then
	echo "/dev/mapper/loop0p2 already exists"
	exit 2;
fi

sudo kpartx -a $IMGFILE

sudo ./create_fs.sh  /dev/mapper/loop0p2
sudo dd if=../contrib/u-boot/u-boot.sb of=/dev/mapper/loop0p1 bs=512 seek=4

MOUNTPOINT=`mktemp -d`
sudo mount /dev/mapper/loop0p2 $MOUNTPOINT
sudo cp -rp $ROOTFS/. $MOUNTPOINT/
sync
sync
sudo umount $MOUNTPOINT
sudo rmdir $MOUNTPOINT
sudo kpartx -d $IMGFILE
