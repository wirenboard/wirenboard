#!/bin/bash
set -e
#set -x

[[ "$#" == "3" ]] || {
	echo "Usage: $0 <rootfs> <initramfs_dir> wb2|wb6"
	exit 1
}

FLAVOUR=$3

case $FLAVOUR in
wb2)
    LIBDIR=/lib/arm-linux-gnueabi
    ;;
wb6)
    LIBDIR=/lib/arm-linux-gnueabihf
    ;;
*)
    echo "Wrong board type, use wb2 or wb6"
    exit 1
    ;;
esac

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
install_dir "/tmp"

install_dir "/sbin"
install_dir "/usr/bin"
install_dir "/usr/sbin"

mknod "$INITRAMFS/dev/console" c 5 1

install_file "$FILES_DIR/init" "/init"
install_file "$FILES_DIR/shadow" "/etc/shadow"
install_file "$FILES_DIR/fstab" "/etc/fstab"
install_file "$FILES_DIR/dropbear_rsa_host_key" "/etc/dropbear/dropbear_rsa_host_key"
install_file "$FILES_DIR/dropbear_dss_host_key" "/etc/dropbear/dropbear_dss_host_key"
install_file "$FILES_DIR/udhcpd.conf" "/etc/udhcpd.conf"
install_file "$FILES_DIR/usb_net.sh" "/bin/usb_net"
install_file "$FILES_DIR/libupdate.wb5.sh" "/lib/libupdate.wb5.sh"
install_file "$FILES_DIR/libupdate.wb6.sh" "/lib/libupdate.wb6.sh"
install_file "$FILES_DIR/wait_for_button.sh" "/bin/wait_for_button"

[[ $FLAVOUR == "wb2" ]] && {
    arm-linux-gnueabi-gcc -o $FILES_DIR/memdump $FILES_DIR/memdump.c -Wall -Wextra -pedantic -std=c99
    install_file "$FILES_DIR/memdump" "/bin/memdump"
}

case $FLAVOUR in
wb2)
    install_from_rootfs /usr/share/wb-configs/u-boot/fw_env.config.wb.mxs /etc/fw_env.config
    ;;
wb6)
    install_from_rootfs /usr/share/wb-configs/u-boot/fw_env.config.wb.imx6 /etc/fw_env.config
    ;;
wb7)
    install_from_rootfs /usr/share/wb-configs/u-boot/fw_env.config.wb.sun8i /etc/fw_env.config
    ;;
esac

FROM_ROOTFS=(
	/bin/busybox
	/bin/bash
	/usr/bin/fw_printenv
	/usr/bin/fw_setenv
    /etc/profile
	/usr/bin/fit_info
	/usr/bin/pv
    /sbin/mkfs.ext4
	/usr/bin/wb-run-update
    /usr/sbin/dropbear
    /usr/bin/dropbearkey

    $LIBDIR/libnss_files.so.2
    $LIBDIR/libnss_files-2.24.so
    $LIBDIR/ld-2.24.so
    $LIBDIR/ld-linux.so.3

    /etc/shadow
    /etc/group
    /bin/login
    /bin/openvt
    /usr/bin/scp
    /usr/bin/unshare

    /sbin/sfdisk
    /usr/lib/wb-prepare/vars.sh
    /usr/lib/wb-prepare/partitions.sh
    /usr/bin/rsync
    /usr/bin/mmc
    /bin/dd
    /sbin/dumpe2fs
    /sbin/resize2fs
)

for f in "${FROM_ROOTFS[@]}"; do
	install_from_rootfs "$f"
done

echo 'root:x:0:0:root:/:/bin/sh' > $INITRAMFS/etc/passwd
