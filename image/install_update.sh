#!/bin/bash -x
this="`readlink -f $0`"

die() {
	>&2 echo "!!! $@"
	[[ $? == 0 ]] && exit 1 || exit $?
}

info() {
	>&2 echo ">>> $@"
}

extract_blob_body() {
	# extracts lines from $1 to $2, trimming trailing \n
	local begin=$1
	local end=$2

	awk '
		NR >= '$begin' {
			q=p
			p=$0
		}
		NR > '$begin' {
			print q
		}
		NR == '$end' {
			ORS=""
			print p
			exit 0
		}' "$this"
}

# Find blob boundaries and expected MD5
find_blob() {
	local tag=$1

	local tmp=`awk '
		/^__BLOB_BEGIN__:'"$tag"':$/ {
			begin=NR+1
		}
		match($0, /^__BLOB_END__:'"$tag"':([0-9a-f]+)$/, a) {
			print begin, NR-1, a[1]
			exit 0
		}' "$this"`
	local begin="${tmp%% * *}"
	local end="${tmp#* }"
	local md5_expected="${end#* }"
	end="${end% *}"

	[[ -n "$begin" && -n "$end" && -n "$md5_expected" ]] && {
		echo "$tag $begin $end $md5_expected"
	} || {
		die "Blob $tag not found"
	}
}

verify_blob() {
	local tag=$1
	local begin=$2
	local end=$3
	local md5_expected=$4

	info "Checking MD5 checksum of $tag"
	local md5_calculated=`extract_blob_body $begin $end | md5sum | cut -f1 -d' '`
	[[ "$md5_expected" == "$md5_calculated" ]] &&
		info "MD5 checksum of $tag ok" ||
		die "MD5 of $tag doesn't match (expected $md5_expected, got $md5_calculated)"
}

extract_tarball() {
	local tag=$1
	local begin=$2
	local end=$3
	local dst=$5

	info "Unpacking $tag into $dst"
	pushd $dst
	extract_blob_body $begin $end | tar xjvp
	popd
}

[[ $EUID != 0 ]] && die "Need root privileges to install update"

blob=`find_blob ROOTFS`
verify_blob $blob

info "Installing firmware update"

tmpdir='/dev/shm'
mnt="$tmpdir/rootfs"

declare -a partitions=( 
	''
	'uboot'
	'rootfs0'
	'rootfs1'
	''
	'swap'
	'data'
)

root_dev='mmcblk0'
part=`readlink /dev/root`
part=${part##*${root_dev}p}
case "$part" in
	2)
		part=3
		;;
	3)
		part=2
		;;
	*)
		die "Unable to determine second rootfs partition (current is $part)"
		;;
esac
root_part=/dev/${root_dev}p${part}
info "Will install to $root_part"

umount -f $root_part 2&>1 >/dev/null || true # just for sure
info "Formatting $root_part"
yes | mkfs.ext4 -L "${partitions[$part]}" -E stride=2,stripe-width=1024 -b 4096 "$root_part" || die "mkfs.ext4 failed"

info "Mounting $root_part to $mnt"
rm -rf "$mnt" && mkdir "$mnt" || die "Unable to create mountpoint $mnt"
mount -t ext4 "$root_part" "$mnt" || die "Unable to mount just created filesystem"

extract_tarball $blob "$mnt"

info "Done"
