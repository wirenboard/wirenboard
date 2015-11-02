#!/bin/bash
# need sudo apt-get install multipath-tools
set -e
if [ $# -ne 3 ]; then
	echo "USAGE: $0 <path to rootfs> <path to u-boot> <img file>"
	exit 1
fi

ROOTFS="$1"
UBOOT="$2"
IMGFILE="$3"

if [ "$IMGFILE" == "/dev/sda" ]; then
	echo "Attempt to rewrite sda part table";
	exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exec sudo "$0" "$@"
fi

PATH=/sbin:$PATH
SECTOR_SIZE=512
MB=1024*1024

# create image file
DATASIZE=`sudo du -sm $ROOTFS | cut -f1`
IMGSIZE=$[DATASIZE + 100] # in megabytes
PART_START=$[4*MB/SECTOR_SIZE]
TOTAL_SECTORS=$[IMGSIZE*MB/SECTOR_SIZE]

truncate -s ${IMGSIZE}M $IMGFILE

# Generates single partition definition line for sfdisk.
# Increments PART_START variable to point to the start of the next partition
# (special case is Extended (5) fstype, which increments PART_START by 2048 sectors)
# Args:
# - size in megabytes (or '' to use all remaining space to the end)
# - filesystem type (looks like not really matters). when omitted, defaults to 83 (Linux)
wb_partition()
{
    [[ -z "$1" ]] &&
        local size=$[TOTAL_SECTORS-PART_START] ||
        local size=$[$1*MB/SECTOR_SIZE]
    local fstype=${2:-83}
    echo "$PART_START $size $fstype"
    [[ "$fstype" == 5 ]] && ((PART_START+=2048)) || ((PART_START+=$size))
}

dd if=/dev/zero of=$IMGFILE bs=1M count=5 conv=notrunc
{
	wb_partition 16 53
	wb_partition
} | sfdisk --in-order --Linux --unit=S  $IMGFILE


DEV=/dev/mapper/`sudo kpartx -av $IMGFILE | sed -rn 's#.* (loop[0-9]+p).*#\1#p; q'`

sudo dd if=$UBOOT of=${DEV}1 bs=$SECTOR_SIZE seek=4

sudo mkfs.ext4 ${DEV}2 -E stride=2,stripe-width=1024 -b 4096 -L rootfs
MOUNTPOINT=`mktemp -d`
sudo mount ${DEV}2 $MOUNTPOINT/

cleanup() {
	sudo umount $MOUNTPOINT
	sudo rmdir $MOUNTPOINT
	sync
	sync
	sudo kpartx -d $IMGFILE
}
trap cleanup EXIT

# remove some usual development garbage
chroot $ROOTFS apt-get clean || true
rm -rf $ROOTFS/run/* $ROOTFS/var/cache/apt/* $ROOTFS/var/lib/apt/lists/* \
	$ROOTFS/usr/sbin/policy-rc.d \
	$ROOTFS/*.deb

sudo cp -a $ROOTFS/. $MOUNTPOINT/

echo "Done!"
exit 0
