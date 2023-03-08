#!/bin/bash
set -e

# FIXME: transitional definitions which are being moved to wb-run-update
HIDDENFS_PART=/dev/mmcblk0p1
HIDDENFS_OFFSET=$((8192*512))  # 8192 blocks of 512 bytes
DEVCERT_NAME="device.crt.pem"
INTERM_NAME="intermediate.crt.pem"
ROOTFS_CERT_PATH="/etc/ssl/certs/device_bundle.crt.pem"

type fit_prop_string 2>/dev/null | grep -q 'shell function' || {
    fit_prop_string() {
        fit_prop "$@" | tr -d '\0'
    }
}

type mkfs_ext4 2>/dev/null | grep -q 'shell function' || {
    mkfs_ext4() {
        local part=$1
        local label=$2

        yes | mkfs.ext4 -L "$label" -E stride=2,stripe-width=1024 -b 4096 "$part"
    }
}


check_compatible() {
	local fit_compat=`fit_prop_string / compatible`
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
ACTUAL_DEB_RELEASE=""

ROOT_DEV='mmcblk0'
if [[ -e "/dev/root" ]]; then
	PART=`readlink /dev/root`
	PART=${PART##*${ROOT_DEV}p}
else
	info "Getting mmcpart from U-Boot environment"
	PART=$(fw_printenv mmcpart | sed 's/.*=//') || PART=""
fi

case "$PART" in
	2)
		PART=3
		PART_NOW=2
		PARTLABEL=rootfs1
		;;
	3)
		PART=2
		PART_NOW=3
		PARTLABEL=rootfs0
		;;
	*)
		flag_set from-initramfs && {
			info "Update is started from initramfs and unable to determine active rootfs partition, will overwrite rootfs0"
			PART=2
			PART_NOW=3
			PARTLABEL=rootfs0
		} || {
			die "Unable to determine second rootfs partition (current is $PART)"
		}
		;;
esac
ROOT_PART=/dev/${ROOT_DEV}p${PART}
info "Will install to $ROOT_PART"

rm -rf "$MNT" && mkdir "$MNT" || die "Unable to create mountpoint $MNT"

flag_set "from-initramfs" && {
    actual_rootfs=/dev/${ROOT_DEV}p${PART_NOW}
    info "Check if partition table is correct"
    [[ -e $ROOT_PART ]] && [[ -e $actual_rootfs ]] || {
        die "rootfs partition doesn't exist, looks like partitions table is broken. Give up."
    }
    info "Temporarily mount actual rootfs $actual_rootfs to check os-release"
    mount -t ext4 $actual_rootfs $MNT 2>&1 >/dev/null && {
        sync
        ACTUAL_DEB_RELEASE="$(MNT="$MNT" bash -c 'source "$MNT/etc/os-release"; echo $VERSION_CODENAME')"
        umount -f $actual_rootfs 2>&1 >/dev/null || true
    } || true
}

# determine if new partition is unformatted
mount -t ext4 $ROOT_PART $MNT 2>&1 >/dev/null || {
    info "Unable to mount root partition, formatting $ROOT_PART"
    mkfs_ext4 $ROOT_PART $PARTLABEL || die "mkfs.ext4 failed"
}

umount -f $ROOT_PART 2>&1 >/dev/null || true # just for sure

info "Mounting $ROOT_PART at $MNT"
mount -t ext4 "$ROOT_PART" "$MNT" 2>&1 >/dev/null|| die "Unable to mount root filesystem"

[[ -z "$ACTUAL_DEB_RELEASE" ]] && ACTUAL_DEB_RELEASE="$(MNT="$MNT" bash -c 'source "$MNT/etc/os-release"; echo $VERSION_CODENAME')"
upcoming_deb_release="$(fit_prop_string / release-target | sed 's/wb[[:digit:]]\+\///')"
info "Debian: $ACTUAL_DEB_RELEASE -> $upcoming_deb_release"
if [ "$ACTUAL_DEB_RELEASE" = "bullseye" ] && [ "$upcoming_deb_release" = "stretch" ]; then
    if ! flag_set factoryreset; then
        >&2 cat <<EOF
##############################################################################

    UPGRADE FROM $ACTUAL_DEB_RELEASE TO $upcoming_deb_release REQUESTED

                    Due to major Debian release changes,
                this operation is allowed only via FACTORYRESET.

           This WILL destroy ALL YOUR DATA: configuration, scripts,
                           files in home directory!

    Rename .fit file to "wbX_update_FACTORYRESET.fit" ->
    put renamed file to usb-drive ->
    ensure, there is only one .fit file on usb-drive ->
    insert usb-drive to controller and reboot ->
    follow further factoryreset instructions.

##############################################################################
EOF
        if flag_set from-initramfs; then
            led_failure
            bash -c 'source /lib/libupdate.sh; buzzer_init; buzzer_on; sleep 1; buzzer_off'
            info "Rebooting..."
            reboot -f
        else
            die "Aborting..."
        fi
    fi
fi

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

if ! flag_set no-certificates; then
    info "Recovering device certificates"
    HIDDENFS_MNT=$TMPDIR/hiddenfs
    mkdir -p $HIDDENFS_MNT

    # make loop device
    LO_DEVICE=`losetup -f`
    losetup -r -o $HIDDENFS_OFFSET $LO_DEVICE $HIDDENFS_PART ||
        die "Failed to add loopback device"

    if mount $LO_DEVICE $HIDDENFS_MNT 2>&1 >/dev/null; then
        cat $HIDDENFS_MNT/$INTERM_NAME $HIDDENFS_MNT/$DEVCERT_NAME > $MNT/$ROOTFS_CERT_PATH ||
            info "WARNING: Failed to copy device certificate bundle into new rootfs. Please report it to info@contactless.ru"
        umount $HIDDENFS_MNT
        sync
    else
        info "WARNING: Failed to find certificates of device. Please report it to info@contactless.ru"
    fi
fi

if ! flag_set no-postinst; then
    info "Mount /dev, /proc and /sys to rootfs"
    mount -o bind /dev "$MNT/dev"
    mount -o bind /proc "$MNT/proc"
    mount -o bind /sys "$MNT/sys"

    POSTINST_DIR="$MNT/usr/lib/wb-image-update/postinst/"
    if [[ -d "$POSTINST_DIR" ]]; then
        info "Running post-install scripts"

        POSTINST_FILES="$(find "$POSTINST_DIR" -maxdepth 1 -type f | sort)"
        for file in $POSTINST_FILES; do
            info "> Processing $file"
            FIT="$FIT" "$file" "$MNT" "$FLAGS" || true
        done
    fi

    info "Unmounting /dev, /proc and /sys from rootfs"
    umount "$MNT/dev"
    umount "$MNT/proc"
    umount "$MNT/sys"
fi

info "Switching to new rootfs"
fw_setenv mmcpart $PART
fw_setenv upgrade_available 1

info "Done!"
rm_fit
led_success || true

if ! flag_set no-reboot; then
    info "Unmounting new rootfs"
    umount $MNT
    sync; sync

    info "Reboot system"
    mqtt_status REBOOT
    trap EXIT
    flag_set "from-initramfs" && {
        sync
        reboot -f
    } || reboot
fi
exit 0
