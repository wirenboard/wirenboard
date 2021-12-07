#!/bin/bash
# need sudo apt-get install multipath-tools
set -e
set -x
if [ $# -ne 4 ]; then
	echo "USAGE: $0 <soc_type> <path to rootfs> <path to u-boot.sb or u-boot.sd> <path to img file>"
    echo "<soc_type> should be either mx23 or mx28 or mx6ul or sun8i_r40"

	exit 1
fi

SOC_TYPE="$1"
ROOTFS="$2"
UBOOT="$3"
IMGFILE="$4"

UBOOT_BASENAME=$(basename "$UBOOT")

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
echo "$DATASIZE"
IMGSIZE=$[DATASIZE + 120] # in megabytes
TOTAL_SECTORS=$[IMGSIZE*MB/SECTOR_SIZE]
echo "IMGSIZE: $IMGSIZE"

PART_START_mx23=$[4*MB/SECTOR_SIZE]
write_uboot_mx23() {
	sudo dd if=$UBOOT of=${DEV}p1 bs=$SECTOR_SIZE seek=4
}

PART_START_mx28=$[1*MB/SECTOR_SIZE]
write_uboot_mx28() {
	sudo dd if=$UBOOT of=${DEV}p1
}

PART_START_mx6ul=$[1*MB/SECTOR_SIZE]
write_uboot_mx6ul() {
	sudo dd if=$UBOOT of=${IMGFILE} bs=$SECTOR_SIZE seek=2 conv=notrunc,fdatasync
}

PART_START_sun8i_r40=$[1*MB/SECTOR_SIZE]
write_uboot_sun8i_r40() {
    sudo dd if=$UBOOT of=${IMGFILE} bs=1024 seek=8 conv=notrunc,fdatasync
}

eval "PART_START=\${PART_START_${SOC_TYPE}}"

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

dd if=/dev/zero of=$IMGFILE bs=1M count=5 conv=notrunc,fdatasync
{
	wb_partition 16 53
	wb_partition
} | sfdisk  --Linux --unit=S  $IMGFILE

sync

DEV=/dev/mapper/`sudo kpartx -av $IMGFILE | sed -rn 's#.* (loop[0-9]+)p.*#\1#p; q'`
sync
sleep 3

write_uboot_${SOC_TYPE}

ls -lh  ${DEV}p2

E2FS_FEATURES=has_journal,ext_attr,resize_inode,dir_index,filetype,extent,flex_bg,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize
sudo mkfs.ext4 ${DEV}p2 -E stride=2,stripe-width=1024 -i 8192 -Onone,$E2FS_FEATURES,^64bit -b 4096 -L rootfs
MOUNTPOINT=`mktemp -d`
sudo mount ${DEV}p2 $MOUNTPOINT/

cleanup() {
	sudo umount $MOUNTPOINT
	sudo rmdir $MOUNTPOINT
	sync
	sudo e2fsck -f -p ${DEV}p2
	sync
	sudo kpartx -d $IMGFILE
}
trap cleanup EXIT

# remove some usual development garbage
chroot $ROOTFS apt-get clean || true
rm -rf $ROOTFS/run/* $ROOTFS/var/cache/apt/archives/* $ROOTFS/var/lib/apt/lists/* \
	$ROOTFS/usr/sbin/policy-rc.d \
	$ROOTFS/*.deb

sudo cp -a $ROOTFS/. $MOUNTPOINT/

echo "Done!"
exit 0
