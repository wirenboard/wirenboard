#!/bin/bash
set -e

if [ $# -lt 2 ] || [ $# -gt 3 ] ; then
    echo "USAGE <path to rootfs> <board> [version]"
	exit 1
fi

ROOTFS=$1
BOARD=$2

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || die "Unable to get firmware version"
echo "FW version: $VERSION"

if [ ! -z "$3" ]; then
    VERSION=$3
    echo "FW version overriden: $VERSION"
fi

for MEM in alliance hynix; do
    mkdir -p "image/${BOARD}"
    IMG_NAME="image/${BOARD}/${VERSION}_sdcard_${BOARD}_${MEM}.img"
    WEBUPD_NAME="image/${BOARD}/${VERSION}_webupd_${BOARD}_${MEM}.fit"


    rm -f ${IMG_NAME}
    ./create_image.sh mx23 ${ROOTFS} ../contrib/u-boot/u-boot.sb.wb4_${MEM}  ${IMG_NAME}
    zip ${IMG_NAME}.zip ${IMG_NAME}
    ./create_update.sh ${ROOTFS} ${WEBUPD_NAME}

    echo "${MEM} done"
    echo  ${IMG_NAME}
    echo  ${IMG_NAME}.zip
    echo  ${WEBUPD_NAME}
done;

echo "done"
echo "FW version: $VERSION"




