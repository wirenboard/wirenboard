#!/bin/bash
set -e
set -x

this=`readlink -f "$0"`

INSTALL_SCRIPT="`dirname $this`/install_update.sh"

usage() {
	cat <<EOF
USAGE: $0 <path to rootfs> <path to zImage> <update file>"
rootfs can be either a directory (which will be packed to .tar.xz) 
or just anything suitable for $(dirname $0)/install_update.sh.sh
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

[[ $# != 3 ]] && usage

ROOTFS=$(readlink -f $1)
ZIMAGE=$(readlink -f $2)
OUTPUT=$(readlink -f $3)

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
	DTB_DIR=$ROOTFS/boot/dtbs
	[[ -h "$DTB_DIR" ]] && DTB_DIR="$ROOTFS/$(readlink $DTB_DIR)"
	DTB=$DTB_DIR/`sed -n 's/^fdt_file=\/boot\/dtbs\///p' $ROOTFS/boot/uEnv.txt`
	[[ -e "$DTB" ]] || die "Unable to get DTB path"
	ROOTFS_TARBALL="$TMPDIR/rootfs.tar.gz"

	echo "Creating rootfs tarball"
	pushd "$ROOTFS" >/dev/null
	sudo tar czp --numeric-owner ./ > "$ROOTFS_TARBALL" || die "tarball of $ROOTFS creation failed"
	popd >/dev/null

	unset DTB_DIR
elif [[ -e "$ROOTFS" ]]; then
	ROOTFS_TARBALL=$ROOTFS
	DTB=`tar xf "$ROOTFS_TARBALL" ./boot/uEnv.txt -O | sed -n 's/^fdt_file=//p'`
	[[ -n "$DTB" ]] || die "Unable to get DTB path"
	tar xf "$ROOTFS_TARBALL" ".$DTB" -h -O > $TMPDIR/update.dtb || die "Unable to extract DTB from rootfs tarball"
	DTB=$TMPDIR/update.dtb
fi

COMPATIBLE=`dtb_get_compatible < "$DTB"`
[[ -n "$COMPATIBLE" ]] || die "Unable to get 'compatible' DTB param"

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || die "Unable to get firmware version"

ITS=$TMPDIR/update.its

{
cat <<EOF
/dts-v1/;

/ {
	description = "WirenBoard firmware update";
	compatible = "$COMPATIBLE";
	firmware-version = "$VERSION";
	firmware-compatible = "unknown";
	#address-cells = <1>;
	images {
EOF
	include kernel $ZIMAGE "Update kernel" "type = \"kernel\"; os = \"linux\"; arch = \"arm\";"
	include dtb $DTB "Update DTB" "type = \"flat_dt\"; arch = \"arm\";"
	include install $INSTALL_SCRIPT "Installation script (bash)"
	include rootfs $ROOTFS_TARBALL "Root filesystem tarball"
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
