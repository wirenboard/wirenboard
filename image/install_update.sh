#!/bin/bash
set -e


check_compatible() {
	local fit_compat=`fit_prop / compatible`
	[[ -z "$fit_compat" || "$fit_compat" == "unknown" ]] && return 0
	for compat in `tr < /proc/device-tree/compatible  '\000' '\n'`; do
		[[ "$fit_compat" == "$compat" ]] && return 0
	done
	return 1
}

if flag_set "force-compatible"; then
	info "WARNING: Don't check compatibility. I hope you know what you're doing..."
else
	check_compatible || die "This update is incompatible with this device"
fi

fit_blob_verify_hash rootfs

info "Installing firmware update"

MNT="$TMPDIR/rootfs"

ROOT_DEV='mmcblk0'
PART=`readlink /dev/root`
if [[ -n "$PART" ]]; then
	PART=${PART##*${ROOT_DEV}p}
else
	info "Getting mmcpart from U-Boot environment"
	PART=$(fw_printenv mmcpart | sed 's/.*=//')
fi

case "$PART" in
	2)
		PART=3
		PARTLABEL=rootfs1
		;;
	3)
		PART=2
		PARTLABEL=rootfs0
		;;
	*)
		flag_set from-initramfs && {
			info "Update is started from initramfs and unable to determine active rootfs partition, will overwrite rootfs0"
			PART=2
			PARTLABEL=rootfs0
		} || {
			die "Unable to determine second rootfs partition (current is $PART)"
		}
		;;
esac
ROOT_PART=/dev/${ROOT_DEV}p${PART}
info "Will install to $ROOT_PART"

umount -f $ROOT_PART 2&>1 >/dev/null || true # just for sure
info "Formatting $ROOT_PART"
yes | mkfs.ext4 -L "$PARTLABEL" -E stride=2,stripe-width=1024 -b 4096 "$ROOT_PART" || die "mkfs.ext4 failed"


info "Mounting $ROOT_PART at $MNT"
rm -rf "$MNT" && mkdir "$MNT" || die "Unable to create mountpoint $MNT"
mount -t ext4 "$ROOT_PART" "$MNT" || die "Unable to mount just created filesystem"

info "Extracting files to new rootfs"
pushd "$MNT"
blob_size=`fit_blob_size rootfs`
(
	echo 0
	fit_blob_data rootfs | pv -n -s "$blob_size" | tar xzp
) 2>&1 | mqtt_progress "$x"
popd

info "Unmounting new rootfs"
umount $MNT
sync; sync

info "Switching to new rootfs"
fw_setenv mmcpart $PART
fw_setenv upgrade_available 1

info "Done, removing firmware image and rebooting"
rm_fit
echo 255 > /sys/class/leds/green/brightness || true
mqtt_status REBOOT
trap EXIT
reboot
exit 0
