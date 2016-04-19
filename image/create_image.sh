#!/bin/bash
# need sudo apt-get install multipath-tools
set -e
set -x
if [ $# -ne 4 ]; then
	echo "USAGE: $0 <soc_type> <path to rootfs> <path to u-boot.sb or u-boot.sd> <path to img file>"
    echo "<soc_type> should be either mx23 or mx28"

	exit 1
fi

ROOTFS="$2"
UBOOT="$3"
IMGFILE="$4"

UBOOT_BASENAME=$(basename "$UBOOT")

case "$1" in
    "mx23")
        SOC_TYPE="MX23"
        ;;
    "mx28")
        SOC_TYPE="MX28"
        ;;
    *)
        echo "Can't determine SoC type"
esac


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
IMGSIZE=$[DATASIZE + 250] # in megabytes
TOTAL_SECTORS=$[IMGSIZE*MB/SECTOR_SIZE]
echo "IMGSIZE: $IMGSIZE"

PART_START_MX23=$[4*MB/SECTOR_SIZE]
write_uboot_MX23() {
	sudo dd if=$UBOOT of=${DEV}1 bs=$SECTOR_SIZE seek=4
}

PART_START_MX28=$[1*MB/SECTOR_SIZE]
write_uboot_MX28() {
	sudo dd if=$UBOOT of=${DEV}1
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

DEV=/dev/mapper/`sudo kpartx -av $IMGFILE | sed -rn 's#.* (loop[0-9]+p).*#\1#p; q'`
sync
sleep 3

write_uboot_${SOC_TYPE}

ls -lh  ${DEV}2

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
rm -rf $ROOTFS/run/* $ROOTFS/var/cache/apt/archives/* $ROOTFS/var/lib/apt/lists/* \
	$ROOTFS/usr/sbin/policy-rc.d \
	$ROOTFS/*.deb

sudo cp -a $ROOTFS/. $MOUNTPOINT/

echo "Done!"
exit 0
