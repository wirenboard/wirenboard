#!/bin/bash
set -e
set -x

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

usage() {
	cat <<EOF
USAGE: $0 <path to rootfs> <path to zImage> <path to boot DTB> <path to target DTB> <update file>"
rootfs can be either a directory (which will be packed to .tar.xz) 
or just anything suitable for $(dirname $0)/install_update.sh
EOF
	exit 1
}

die() {
	local ret=$?
	>&2 echo "!!! $@"
	exit $ret
}

info() {
	>&2 echo ">>> $@"
}

[[ $# != 5 ]] && usage

ROOTFS=$(readlink -f $1)
DEFAULT_ZIMAGE=$(readlink -f $2)
DEFAULT_BOOT_DTB=$(readlink -f $3)
TARGET_DTB=$(readlink -f $4)
OUTPUT=$(readlink -f $5)

[[ -e "$ROOTFS" ]] || die "$ROOTFS not found"

TMPDIR=`mktemp -d`
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT



dtb_get_compatible() {
	fdtget - / compatible | sed 's/ .*$//'
}

if [[ -d "$ROOTFS" ]]; then
	ROOTFS_TARBALL="$TMPDIR/rootfs.tar.gz"

	echo "Creating rootfs tarball"
	pushd "$ROOTFS" >/dev/null
	# to speedup FIT installing, rootfs files should be sorted (dtbs at the beginning)
	sorted_files_list=`mktemp`
	find . | sort > $sorted_files_list
	sudo tar czpf "$ROOTFS_TARBALL" --numeric-owner --no-recursion --files-from=$sorted_files_list || die "tarball of $ROOTFS creation failed"
	rm $sorted_files_list
	popd >/dev/null
elif [[ -e "$ROOTFS" ]]; then
	ROOTFS_TARBALL=$ROOTFS
	ROOTFS=$TMPDIR
	tar xvf $ROOTFS_TARBALL -C $ROOTFS \
	    ./etc/wb-fw-version \
	    ./usr/lib/wb-release \
	    ./var/lib/wb-image-update/firmware-compatible \
	    ./var/lib/wb-image-update/install_update.sh
fi

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || die "Unable to get firmware version"
source $ROOTFS/usr/lib/wb-release || die "Unable to get release information"

ROOTFS_INSTALL_SCRIPT_PATH="$ROOTFS/var/lib/wb-image-update/install_update.sh"
if [[ -e "$ROOTFS_INSTALL_SCRIPT_PATH" ]]; then
	echo "Using install script from rootfs ($ROOTFS_INSTALL_SCRIPT_PATH)"
	INSTALL_SCRIPT="$ROOTFS_INSTALL_SCRIPT_PATH"
else
	echo "No install script in rootfs, using default one"
	INSTALL_SCRIPT="$SCRIPT_DIR/install_update.sh"
fi

ROOTFS_FIRMWARE_COMPATIBLE_PATH="$ROOTFS/var/lib/wb-image-update/firmware-compatible"
if [[ -e "$ROOTFS_FIRMWARE_COMPATIBLE_PATH" ]]; then
    echo "Using firmware-compatible from rootfs ($ROOTFS_FIRMWARE_COMPATIBLE_PATH)"
    FIRMWARE_COMPATIBLE=$(cat "$ROOTFS_FIRMWARE_COMPATIBLE_PATH")
else
    echo "No firmware-compatible in rootfs, using default one"
    FIRMWARE_COMPATIBLE="unknown"
fi

case "$ARCH" in
    arm64)
        KERNEL_IMAGE_NAME="Image.gz"
        ;;
    armhf|armel)
        KERNEL_IMAGE_NAME="zImage"
        ;;
    *)
        die "Unsupported architecture: $ARCH"
        ;;
esac

ROOTFS_BOOTLET_ZIMAGE_PATH="$ROOTFS/var/lib/wb-image-update/$KERNEL_IMAGE_NAME"
if [[ -e "$ROOTFS_BOOTLET_ZIMAGE_PATH" ]]; then
    echo "Using bootlet zImage from rootfs ($ROOTFS_BOOTLET_ZIMAGE_PATH)"
    ZIMAGE="$ROOTFS_BOOTLET_ZIMAGE_PATH"
else
    echo "No bootlet zImage in rootfs, using default one"
    ZIMAGE="$DEFAULT_ZIMAGE"
fi

ROOTFS_BOOT_DTB_PATH="$ROOTFS/var/lib/wb-image-update/boot.dtb"
if [[ -e "$ROOTFS_BOOT_DTB_PATH" ]]; then
    echo "Using bootlet DTB from rootfs ($ROOTFS_BOOT_DTB_PATH)"
    BOOT_DTB="$ROOTFS_BOOT_DTB_PATH"
else
    echo "No bootlet DTB in rootfs, using default one"
    BOOT_DTB="$DEFAULT_BOOT_DTB"
fi

if [[ -e "$TARGET_DTB" ]]; then
    echo "Using compatible from target DTB ($TARGET_DTB)"
    COMPATIBLE=$(dtb_get_compatible < "$TARGET_DTB")
    [[ -n "$COMPATIBLE" ]] || die "Unable to get 'compatible' DTB param"
else
    echo "Using compatible from boot DTB ($BOOT_DTB)"
    COMPATIBLE=$(dtb_get_compatible < "$BOOT_DTB")
    [[ -n "$COMPATIBLE" ]] || die "Unable to get 'compatible' DTB param"
fi

ITS=$TMPDIR/update.its
VARS_FILE="$TMPDIR/vars.env"

cat > "$VARS_FILE" <<EOF
COMPATIBLE=$COMPATIBLE
FIRMWARE_VERSION=$VERSION
FIRMWARE_COMPATIBLE=$FIRMWARE_COMPATIBLE
RELEASE_NAME=$RELEASE_NAME
RELEASE_SUITE=$SUITE
RELEASE_TARGET=$TARGET
RELEASE_REPO_PREFIX=$REPO_PREFIX
KERNEL_DATA=$ZIMAGE
DTB_DATA=$BOOT_DTB
INSTALL_DATA=$INSTALL_SCRIPT
ROOTFS_DATA=$ROOTFS_TARBALL
EOF

j2 --format=env "$SCRIPT_DIR/update.its.j2" "$VARS_FILE" > "$ITS"

UNALIGNED_OUTPUT=$TMPDIR/unaligned.fit

mkimage -v \
	-D "-I dts -O dtb -p 2000" \
	-f "$ITS" \
	-r -k ./ -c "wtf" \
	"$UNALIGNED_OUTPUT" || {
	echo "Failed ITS:"
	cat "$ITS"
	exit 1
}

echo -en "\n__WB_UPDATE_FIT_END__" >> "$UNALIGNED_OUTPUT"

# align output image it fit-aligner is present
if which fit-aligner; then
    info "fit-aligner is found, aligning output image"
    fit-aligner -i $UNALIGNED_OUTPUT -o $OUTPUT -a 512 /images/kernel /images/dtb
    rm -f $UNALIGNED_OUTPUT
else
    info "Warning: fit-aligner is not present, image is unaligned!"
    mv $UNALIGNED_OUTPUT $OUTPUT
fi
