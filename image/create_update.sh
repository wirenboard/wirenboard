#!/bin/bash

usage() {
	echo "USAGE: $0 <path to rootfs> <update file>"
	exit 1
}

[[ $# != 2 ]] && usage

ROOTFS=$1
OUTPUT=$2

[[ ! -d "$ROOTFS" ]] && {
	echo "$ROOTFS is not a directory"
	usage
}

append_blob() {
	local md5=`mktemp`

	echo "__BLOB_BEGIN__:$tag:"
	tee >( md5sum | cut -f1 -d' ' > "$md5" )
	echo
	echo "__BLOB_END__:$tag:`cat $md5`"
	rm "$md5"
}

append_tarball() {
	local tag=$1
	local src=$2
	
	pushd "$src"
	sudo tar cjp ./ | pv | append_blob $tag || {
		ret=$?
		echo "!!! tarball creation failed"
		exit $ret
	}
	popd
}

{
	cat install_update.sh
	echo "exit 0"
	append_tarball ROOTFS $ROOTFS
	# maybe we want to include into update other parts, such as u-boot or separate /var
} > "$OUTPUT"
chmod +x $OUTPUT
