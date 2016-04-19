#!/bin/bash
set -e

if [ $# -lt 1 ] || [ $# -gt 2 ] ; then
    echo "USAGE <path to rootfs> [version]"
	exit 1
fi

set_fdt() {
    echo "fdt_file=/boot/dtbs/${1}.dtb" > ${2}/boot/uEnv.txt
}

ROOTFS=$1

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || die "Unable to get firmware version"
echo "FW version: $VERSION"

if [ ! -z "$2" ]; then
    VERSION=$2
    echo "FW version overriden: $VERSION"
fi

REVISIONS="52 55"
OUT_DIR="image/wb5/${VERSION}"
mkdir -p ${OUT_DIR}
for ver in ${REVISIONS}; do
    set_fdt imx28-wirenboard${ver} ${ROOTFS}
    IMG_NAME="${OUT_DIR}/${VERSION}_emmc_wb${ver}.img"
    WEBUPD_NAME="${OUT_DIR}/${VERSION}_webupd_wb${ver}.fit"

    rm -f ${IMG_NAME}
    ./create_image.sh mx28 ${ROOTFS} ../contrib/u-boot/u-boot.wb5.sd  ${IMG_NAME}
    zip ${IMG_NAME}.zip ${IMG_NAME}
    ./create_update.sh ${ROOTFS} ${WEBUPD_NAME}
done

echo "Done"
echo  ${OUT_DIR}


