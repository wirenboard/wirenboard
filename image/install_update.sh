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
		die "Unable to determine second rootfs PARTition (current is $PART)"
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
fit_blob_data rootfs | tar xJp
popd

cleanup

info "Switching to new rootfs"
fw_setenv mmcpart $PART

info "Done, removing firmware image and rebooting"
rm_fit
reboot
