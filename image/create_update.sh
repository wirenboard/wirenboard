#!/bin/bash
set -e
set -x

this=`readlink -f "$0"`

usage() {
	cat <<EOF
USAGE: $0 <path to rootfs> <path to zImage> <path to DTB> <update file>"
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

include() {
	local name=$1
	local fpath=$2
	local description=$3
	local extra=$4

	cat <<EOF
		$name {
			description = "$description";
			data = /incbin/("$fpath");
			$extra
			compression = "none";

			hash@1 {
				algo = "sha1";
			};
		};
EOF
}

dtb_get_compatible() {
	fdtget - / compatible | sed 's/ .*$//'
}

if [[ -d "$ROOTFS" ]]; then
	ROOTFS_TARBALL="$TMPDIR/rootfs.tar.gz"
	EXTENDING_TOOLS_TARBALL="$TMPDIR/extending_tools.tar.gz"

	echo "Creating rootfs tarball"
	pushd "$ROOTFS" >/dev/null
	sudo tar czp --numeric-owner ./ > "$ROOTFS_TARBALL" || die "tarball of $ROOTFS creation failed"
	popd >/dev/null

	echo "Creating rootfs extending tools tarball"
	mv "$ROOTFS/var/lib/wb-image-update/deps.tar.gz" "$EXTENDING_TOOLS_TARBALL"
elif [[ -e "$ROOTFS" ]]; then
	ROOTFS_TARBALL=$ROOTFS
fi

COMPATIBLE=`dtb_get_compatible < "$TARGET_DTB"`
[[ -n "$COMPATIBLE" ]] || die "Unable to get 'compatible' DTB param"

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || die "Unable to get firmware version"
source $ROOTFS/usr/lib/wb-release || die "Unable to get release information"

ROOTFS_INSTALL_SCRIPT_PATH="$ROOTFS/var/lib/wb-image-update/install_update.sh"
if [[ -e "$ROOTFS_INSTALL_SCRIPT_PATH" ]]; then
	echo "Using install script from rootfs ($ROOTFS_INSTALL_SCRIPT_PATH)"
	INSTALL_SCRIPT="$ROOTFS_INSTALL_SCRIPT_PATH"
else
	echo "No install script in rootfs, using default one"
	INSTALL_SCRIPT="$(dirname "$this")/install_update.sh"
fi

ROOTFS_FIRMWARE_COMPATIBLE_PATH="$ROOTFS/var/lib/wb-image-update/firmware-compatible"
if [[ -e "$ROOTFS_FIRMWARE_COMPATIBLE_PATH" ]]; then
    echo "Using firmware-compatible from rootfs ($ROOTFS_FIRMWARE_COMPATIBLE_PATH)"
    FIRMWARE_COMPATIBLE=$(cat "$ROOTFS_FIRMWARE_COMPATIBLE_PATH")
else
    echo "No firmware-compatible in rootfs, using default one"
    FIRMWARE_COMPATIBLE="unknown"
fi

ROOTFS_BOOTLET_ZIMAGE_PATH="$ROOTFS/var/lib/wb-image-update/zImage"
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

ITS=$TMPDIR/update.its

{
cat <<EOF
/dts-v1/;

/ {
	description = "WirenBoard firmware update";
	compatible = "$COMPATIBLE";
	firmware-version = "$VERSION";
	firmware-compatible = "$FIRMWARE_COMPATIBLE";
	release-name = "$RELEASE_NAME";
	release-suite = "$SUITE";
	release-target = "$TARGET";
	release-repo-prefix = "$REPO_PREFIX";
	#address-cells = <1>;
	images {
EOF
	include kernel "$ZIMAGE" "Update kernel" "type = \"kernel\"; os = \"linux\"; arch = \"arm\";"
	include dtb "$BOOT_DTB" "Update DTB" "type = \"flat_dt\"; arch = \"arm\";"
	include install "$INSTALL_SCRIPT" "Installation script (bash)"
	include rootfs "$ROOTFS_TARBALL" "Root filesystem tarball"
	include extending_tools "$EXTENDING_TOOLS_TARBALL" "Tools tarball for rootfs extending"
cat <<EOF
	};
	configurations {
	};
};
EOF
} > "$ITS"

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
