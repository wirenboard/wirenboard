#!/bin/bash
set -e
set -x
if [ $# -lt 1 ] || [ $# -gt 2 ] ; then
	echo "USAGE: $0 <board type> [fw version]"
	echo "Override default rootfs path with ROOTFS env var"
	exit 1
fi

BOARD=$1

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$SCRIPT_DIR/../boards/init_board.sh"

[[ -e "$ROOTFS" ]] || {
	echo "$ROOTFS not exists"
	exit 3
}

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || {
	echo "Unable to get firmware version"
	exit 4
}

echo "Board:      $BOARD"
echo "RootFS:     $ROOTFS"
echo "FW version: $VERSION"

if [ ! -z "$2" ]; then
    VERSION=$2
    echo "FW version overriden: $VERSION"
fi


OUT_DIR="${IMAGES_DIR}/${VERSION}"
mkdir -p ${OUT_DIR}
IMG_NAME="${OUT_DIR}/${VERSION}_emmc_wb${BOARD}.img"
WEBUPD_NAME="${OUT_DIR}/${VERSION}_webupd_wb${BOARD}.fit"

rm -f ${IMG_NAME}
$TOP_DIR/image/create_image.sh ${IMAGE_TYPE} ${ROOTFS} ${TOP_DIR}/${U_BOOT} ${IMG_NAME}
zip -j ${IMG_NAME}.zip ${IMG_NAME}

ZIMAGE=/`readlink -f ${ROOTFS}/boot/zImage`"
$TOP_DIR/image/create_update.sh ${ROOTFS} ${ZIMAGE} ${WEBUPD_NAME}

echo "Done"
echo  ${OUT_DIR}
