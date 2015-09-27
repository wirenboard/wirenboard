#!/bin/bash
set -e
this=`readlink -f "$0"`

ROOTFS=$1
OUTPUT=$2
INSTALL_SCRIPT="`dirname $this`/install_update.sh"

usage() {
	cat <<EOF
USAGE: $0 <path to rootfs> <update file>"
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

[[ $# != 2 ]] && usage
[[ -e "$ROOTFS" ]] || die "$ROOTFS not found"

create_tarball() {
	local src=$1
	local tarball=`mktemp`

	pushd "$src" >/dev/null
	sudo tar czp --numeric-owner ./ > "$tarball" || {
		rm -f "$tarball"
		die "tarball of $src creation failed"
	}
	popd >/dev/null
	echo "$tarball"
}

include() {
	local name=$1
	local fpath=$2
	local imagetype=$3
	local description=$4

	cat <<EOF
		$name {
			description = "$description";
			data = /incbin/("$fpath");
			compression = "none";

			hash@1 {
				algo = "sha1";
			};
		};
EOF
}

if [[ -d "$ROOTFS" ]]; then
	ROOTFS_TARBALL=`create_tarball $ROOTFS`
elif [[ -e "$ROOTFS" ]]; then
	ROOTFS_TARBALL=$ROOTFS
fi
ITS=`mktemp`

cleanup() {
	rm -f "$ITS"
	[[ "$ROOTFS_TARBALL" == "$ROOTFS" ]] || rm -f "$ROOTFS_TARBALL"
}
trap cleanup EXIT

{
cat <<EOF
/dts-v1/;

/ {
	description = "WirenBoard firmware update";
	compatible = "imx23-wirenboard41contactless";
	firmware-version = "unknown";
	firmware-compatible = "unknown";
	#address-cells = <1>;
	images {
EOF
	include install $INSTALL_SCRIPT "Installation script (bash)"
	include rootfs $ROOTFS_TARBALL "Root filesystem tarball"
cat <<EOF
	};
	configurations {
	};
};
EOF
} > "$ITS"

mkimage -v \
	-D "-I dts -O dtb -p 2000" \
	-f "$ITS" \
	-r -k ./ -c "wtf" \
	"$OUTPUT"

echo -en "\n__WB_UPDATE_FIT_END__" >> "$OUTPUT"
