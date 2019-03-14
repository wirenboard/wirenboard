#!/bin/bash

UBOOT=$1

if [[ ! -e $UBOOT ]]; then
    echo "Usage: $0 <u-boot>" >&2
    exit 1
fi
UBOOT=`readlink -f $UBOOT`

# check that this u-boot supports automatic bootrestore
if ! grep 'bootrestore' $UBOOT 2>&1 >/dev/null; then
    echo "It looks like this U-boot image doesn't support automatic boot restore. Try a newer one." >&2
    exit 1
fi

UBOOT_SIZE=`du -b $UBOOT | awk '{printf "0x%x",$1}'`
echo "U-boot size is $UBOOT_SIZE" >&2



TMPDIR=`mktemp -d`
CONFIG=$TMPDIR/imx6ull_work.conf
UBOOT_COPY=$TMPDIR/uboot.imx
cp $UBOOT $UBOOT_COPY

cleanup() {
    rm $TMPDIR -rf
}
trap cleanup EXIT

cat > $CONFIG <<EOF
mx6_qsb
hid,1024,0x910000,0x10000000,1G,0x00900000,0x40000
${UBOOT}:dcd
:write,0x82fffffc,0xdead0003
:write,0x82fffff8,${UBOOT_SIZE}
:write,0x82fffff4,0x82000000
${UBOOT_COPY}:load 0x82000000
${UBOOT}:clear_dcd,load,plug,jump header 
EOF

CONFIG_MAIN=$TMPDIR/imx_usb.conf
cat > $CONFIG_MAIN <<EOF
#vid:pid, config_file
0x15a2:0x0080, imx6ull_work.conf
EOF


[[ -z $IMX_USB ]] && IMX_USB=`which imx_usb`
if [[ ! -e $IMX_USB ]]; then
    echo "Can't find imx_usb tool. Please put it into PATH or set IMX_USB" >&2
    exit 1
fi
cat $CONFIG
$IMX_USB -c $TMPDIR
