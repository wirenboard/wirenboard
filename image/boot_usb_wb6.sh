#!/bin/bash
usage() {
	echo "Usage: $0 <u-boot.imx> <command> [args]"
	echo "Commands:"
	echo "	usbgadget <zImage> <dtb>"
	echo "	console"
	exit 1
}

[[ "$#" -ge 2 ]] || usage

UBOOT=$(readlink -f "$1")
[[ -e "$UBOOT" ]] || {
	echo "Can't find U-Boot at $UBOOT"
	exit 2
}

CMD="$2"
shift 2

BOOT_TYPE=""
BODY=""
add_cmd() {
	BODY+="$(echo -e "\n${@}")"
}

case "$CMD" in
	usbgadget)
		ZIMAGE=$(readlink -f "$1")
		DTB=$(readlink -f "$2")

		[[ -e "$ZIMAGE" ]] || {
			echo "Can't find zImage at $ZIMAGE"
			exit 3
		}
		
		[[ -e "$DTB" ]] || {
			echo "Can't find DTB at $DTB"
			exit 3
		}

		BOOT_TYPE=1
		add_cmd "${ZIMAGE}:load 0x82000000"
		add_cmd "${DTB}:load 0x83000000"
		;;

	console)
		BOOT_TYPE=2
		;;

	*)
		usage
esac

[[ -z "$IMX_USB" ]] && IMX_USB=$(which imx_usb)
[[ -e "$IMX_USB" ]] || {
	echo "Can't find imx_usb tool. Please set IMX_USB var or put it into your \$PATH"
	exit 4
}

tmpdir=$(mktemp -d)
cleanup() {
	rm -rf $tmpdir
}
trap cleanup EXIT

cat > $tmpdir/mx6_usb_work.conf <<EOF
mx6_qsb
#hid/bulk,[old_header,]max packet size, dcd_addr, {ram start, ram size}(repeat valid
 ram areas)
hid,1024,0x910000,0x10000000,1G,0x00900000,0x40000
${UBOOT}:dcd
${BODY}
:write,0x82fffffc,$(printf '0xDEAD%04x' ${BOOT_TYPE})
${UBOOT}:clear_dcd,load,plug,jump header
EOF

cat > $tmpdir/imx_usb.conf <<EOF
0x15a2:0x0080, mx6_usb_work.conf
0x15a2:0x007d, mx6_usb_work.conf
EOF

$IMX_USB -c $tmpdir
