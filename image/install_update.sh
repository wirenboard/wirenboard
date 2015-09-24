#!/bin/bash
set -e

fit_blob_verify_hash rootfs

info "Installing firmware update"

MNT="$TMPDIR/rootfs"

declare -a partitions=( 
	''
	'uboot'
	'rootfs0'
	'rootfs1'
	''
	'swap'
	'data'
)

ROOT_DEV='mmcblk0'
PART=`readlink /dev/root`
PART=${PART##*${ROOT_DEV}p}
case "$PART" in
	2)
		PART=3
		;;
	3)
		PART=2
		;;
	*)
		die "Unable to determine second rootfs partition (current is $PART)"
		;;
esac
ROOT_PART=/dev/${ROOT_DEV}p${PART}
info "Will install to $ROOT_PART"

umount -f $ROOT_PART 2&>1 >/dev/null || true # just for sure
info "Formatting $ROOT_PART"
yes | mkfs.ext4 -L "${partitions[$PART]}" -E stride=2,stripe-width=1024 -b 4096 "$ROOT_PART" || die "mkfs.ext4 failed"

cleanup() {
	set +e
	info "Unmounting new rootfs"
	umount $MNT
	sync
}
trap cleanup EXIT

info "Mounting $ROOT_PART at $MNT"
rm -rf "$MNT" && mkdir "$MNT" || die "Unable to create mountpoint $MNT"
mount -t ext4 "$ROOT_PART" "$MNT" || die "Unable to mount just created filesystem"

info "Extracting files to new rootfs"
pushd "$MNT"
blob_size=`fit_blob_size rootfs`
( fit_blob_data rootfs | pv -n -s "$blob_size" | cat >/dev/null ) 2>&1 \
| while read x; do
	mqtt_progress "$x"
done
popd

cleanup

info "Switching to new rootfs"
fw_setenv mmcpart $PART
fw_setenv upgrade_available 1

info "Done, removing firmware image and rebooting"
rm_fit
echo 255 > /sys/class/leds/green/brightness || true
mqtt_status DONE
reboot
