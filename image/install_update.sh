#!/bin/bash
set -e

type fit_prop_string | grep -q 'shell function' || {
    fit_prop_string() {
        fit_prop "$@" | tr -d '\0'
    }
}

# FIXME: move these lines to config, wb_env.sh maybe
HIDDENFS_PART=/dev/mmcblk0p1
HIDDENFS_OFFSET=$((8192*512))  # 8192 blocks of 512 bytes
DEVCERT_NAME="device.crt.pem"
INTERM_NAME="intermediate.crt.pem"
ROOTFS_CERT_PATH="/etc/ssl/certs/device_bundle.crt.pem"

DATA_WIPE_BUTTON_TIMEOUT=10
DATA_PART=/dev/mmcblk0p6
DATA_LABEL="data"

check_compatible() {
	local fit_compat=`fit_prop_string / compatible`
	[[ -z "$fit_compat" || "$fit_compat" == "unknown" ]] && return 0
	for compat in `tr < /proc/device-tree/compatible  '\000' '\n'`; do
		[[ "$fit_compat" == "$compat" ]] && return 0
	done
	return 1
}

mkfs_ext4() {
    local part=$1
    local label=$2

    yes | mkfs.ext4 -L "$label" -E stride=2,stripe-width=1024 -b 4096 "$part"
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
if [[ -e "/dev/root" ]]; then
	PART=`readlink /dev/root`
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

flag_set "from-initramfs" && {
    info "Check if partition table is correct"
    [[ -e $ROOT_PART ]] || {
        die "rootfs partition doesn't exist, looks like partitions table is broken. Give up."
    }
}

rm -rf "$MNT" && mkdir "$MNT" || die "Unable to create mountpoint $MNT"

# determine if new partition is unformatted
mount -t ext4 $ROOT_PART $MNT 2>&1 >/dev/null || {
    info "Unable to mount root partition, formatting $ROOT_PART"
    mkfs_ext4 $ROOT_PART $PARTLABEL || die "mkfs.ext4 failed"
}

umount -f $ROOT_PART 2>&1 >/dev/null || true # just for sure

info "Mounting $ROOT_PART at $MNT"
mount -t ext4 "$ROOT_PART" "$MNT" 2>&1 >/dev/null|| die "Unable to mount root filesystem"

info "Cleaning up $ROOT_PART"
rm -rf /tmp/empty && mkdir /tmp/empty
if which rsync >/dev/null; then
    info "Cleaning up using rsync"
    rsync -a --delete /tmp/empty/ $MNT || die "Failed to cleanup rootfs"
else
    info "Can't find rsync, cleaning up using rm -rf (may be slower)"
    rm -rf $MNT/..?* $MNT/.[!.]* $MNT/* || die "Failed to cleanup rootfs"
fi

info "Extracting files to new rootfs"
pushd "$MNT"
blob_size=`fit_blob_size rootfs`
(
	echo 0
	fit_blob_data rootfs | pv -n -s "$blob_size" | tar xzp || die "Failed to extract rootfs"
) 2>&1 | mqtt_progress "$x"
popd

info "Recovering device certificates"
HIDDENFS_MNT=$TMPDIR/hiddenfs
mkdir -p $HIDDENFS_MNT

# make loop device
LO_DEVICE=`losetup -f`
losetup -r -o $HIDDENFS_OFFSET $LO_DEVICE $HIDDENFS_PART || 
    die "Failed to add loopback device"

if mount $LO_DEVICE $HIDDENFS_MNT 2>&1 >/dev/null; then
    cat $HIDDENFS_MNT/$INTERM_NAME $HIDDENFS_MNT/$DEVCERT_NAME > $MNT/$ROOTFS_CERT_PATH ||
        die "Failed to write device certificate bundle into new rootfs"
    umount $HIDDENFS_MNT
    sync
else
    info "WARNING: Failed to find certificates of device. Please report it to info@contactless.ru"
fi

info "Unmounting new rootfs"
umount $MNT
sync; sync

info "Switching to new rootfs"
fw_setenv mmcpart $PART
fw_setenv upgrade_available 1

# ask user if he wants to wipe data partition
flag_set "from-initramfs" && {
    info "If you want to wipe data partition of this controller, press the button within $DATA_WIPE_BUTTON_TIMEOUT seconds"
    info "DANGER: THIS CAN NOT BE UNDONE"
    button_wait $DATA_WIPE_BUTTON_TIMEOUT && {
        info "Again, after next button press your data will be removed!"
        info "Press the button again if you're ABSOLUTELY sure"
        button_wait $DATA_WIPE_BUTTON_TIMEOUT {
            info "Formatting /mnt/data..."
            umount -f $DATA_PART # just to be sure
            mkfs_ext4 $DATA_PART $DATA_LABEL || die "Failed to format data partition"
        }
    } || info "Data wiping aborted"
}

info "Done, removing firmware image and rebooting"
rm_fit
led_success || true
mqtt_status REBOOT
trap EXIT
flag_set "from-initramfs" && {
	sync
	reboot -f
} || reboot
exit 0
