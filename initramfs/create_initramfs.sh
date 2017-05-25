#!/bin/bash
set -e
#set -x

[[ "$#" == "2" ]] || {
	echo "Usage: $0 <rootfs> <initramfs_dir>"
	exit 1
}

[[ $EUID == 0 ]] || {
	exec sudo -E "$0" "$@"
}

ROOTFS="$(readlink -f "$1")"
INITRAMFS="$(readlink -f "$2")"

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TOP_DIR="$(readlink -f "$SCRIPT_DIR/..")"
FILES_DIR="$SCRIPT_DIR/files"

install_dir() {
	echo "dir $1"
	mkdir -p "$INITRAMFS/$1"
}

install_file() {
	local src="$1"
	local dst="$2"
	
	local dstdir=$(dirname "$dst")
	[[ -d "$INITRAMFS/$dstdir" ]] || install_dir "$dstdir"
	
	echo "file $dst <- $src"
	cp "$src" "$INITRAMFS/$dst"
}

install_from_rootfs() {
	local src="$1"
	local dst="$2"

	[[ -z "$dst" ]] && {
		dst="$src"
		shift
	}
	install_file "$ROOTFS/$src" "$dst"

	# If file is executable, need to get its shared lib dependencies too
	if [[ -x "$ROOTFS/$src" ]]; then
		chroot "$ROOTFS" ldd "$src" |
		sed -rn 's#[^/]*(/[^ ]*).*#\1#p' |
		while read lib; do
			[[ -e "$INITRAMFS/$lib" ]] || install_from_rootfs "$lib"
		done
	fi
}

rm -rf "$INITRAMFS"

install_dir "/dev"
install_dir "/proc"
install_dir "/sys"

install_dir "/sbin"
install_dir "/usr/bin"
install_dir "/usr/sbin"

mknod "$INITRAMFS/dev/console" c 5 1

install_file "$FILES_DIR/init" "/init"
install_file "$FILES_DIR/fstab" "/etc/fstab"

FROM_ROOTFS=(
	/bin/busybox
	/bin/bash
	/usr/bin/fw_printenv
	/usr/bin/fw_setenv
	/etc/fw_env.config
	/usr/bin/fit_info
	/usr/bin/pv
	/sbin/mkfs.ext4
	/usr/bin/wb-run-update
)

for f in "${FROM_ROOTFS[@]}"; do
	install_from_rootfs "$f"
done
