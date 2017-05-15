#!/bin/bash -x
[[ "$#" == "2" ]] || {
	echo "Usage: $0 <u-boot.imx> <zImage>"
	exit 1
}

UBOOT=$(readlink -f "$1")
ZIMAGE=$(readlink -f "$2")

[[ -e "$UBOOT" ]] || {
	echo "Can't find U-Boot at $UBOOT"
	exit 2
}

[[ -e "$ZIMAGE" ]] || {
	echo "Can't find zImage at $zImage"
	exit 3
}

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
${ZIMAGE}:load 0x82000000
${UBOOT}:clear_dcd,load,plug,jump header
EOF

cat > $tmpdir/imx_usb.conf <<EOF
0x15a2:0x0080, mx6_usb_work.conf
0x15a2:0x007d, mx6_usb_work.conf
EOF

$IMX_USB -c $tmpdir
