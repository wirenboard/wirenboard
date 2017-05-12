#!/bin/bash
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

install_file() {
	local src="$1"
	local dst="$2"
	shift 2
	
	echo "$dst <- $src"
	install -D -T "$@" "$src" "$INITRAMFS/$dst"
}

install_from_rootfs() {
	local src="$1"
	local dst="$2"
	shift

	[[ -z "$dst" ]] && {
		dst="$src"
		shift
	}
	install_file "$ROOTFS/$src" "$dst" "$@"
}

rm -rf "$INITRAMFS"

mkdir -p "$INITRAMFS/dev"
mkdir -p "$INITRAMFS/proc"
mkdir -p "$INITRAMFS/sys"

mkdir -p "$INITRAMFS/sbin"
mkdir -p "$INITRAMFS/usr/bin"
mkdir -p "$INITRAMFS/usr/sbin"

mknod "$INITRAMFS/dev/console" c 5 1

install_from_rootfs /bin/busybox
install_file "$FILES_DIR/init" "/init"
install_file "$FILES_DIR/fstab" "/etc/fstab"
