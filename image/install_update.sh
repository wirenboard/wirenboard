#!/bin/bash
set -e
set -x

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
	info "Unmounting chroot mounts"
	umount $MNT/mnt/data
	[[ -L $MNT/dev/ptmx ]] || umount $MNT/dev/ptmx
	umount $MNT/dev/pts
	umount $MNT/dev
	umount $MNT/sys
	umount $MNT/proc
	
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

info "Preparing chroot mounts"
mount -t proc procfs $MNT/proc
mount --bind /sys $MNT/sys
mount --bind /dev $MNT/dev
mount -t devpts devpts $MNT/dev/pts -o "gid=5,mode=620,ptmxmode=666,newinstance"
[[ -L $MNT/dev/ptmx ]] || mount -o bind $MNT/dev/pts/ptmx $MNT/dev/ptmx
mount --bind /mnt/data $MNT/mnt/data

info "Running rc.local script in new rootfs"
chroot $MNT /etc/rc.local

cleanup

info "Switching to new rootfs"
fw_setenv mmcpart $PART

info "Done, rebooting"
reboot
