#!/bin/bash
# need sudo apt-get install multipath-tools

echo "USAGE: $0 <path to rootfs> <path to u-boot> <img file>"
if [ $# -ne 3 ]
then
  exit 1
fi

IMGFILE="$3"
ROOTFS="$1"
UBOOT="$2"



# create image file
DATASIZE=`sudo du -sm $ROOTFS | cut -f1`
IMGSIZE=$((DATASIZE + 100)) # in megabytes

dd if=/dev/zero of=$IMGFILE bs=1M count=$IMGSIZE
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



sudo dd if=$UBOOT of=/dev/mapper/loop0p1 bs=512 seek=4

MOUNTPOINT=`mktemp -d`
sudo mount /dev/mapper/loop0p2 $MOUNTPOINT
sudo cp -rp $ROOTFS/. $MOUNTPOINT/
sync
sync
sudo umount $MOUNTPOINT
sudo rmdir $MOUNTPOINT
sudo kpartx -d $IMGFILE
