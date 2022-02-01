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

. $ROOTFS/usr/lib/wb-release || {
    echo "Unable to get release info"
    exit 4
}

. $ROOTFS/usr/lib/os-release || {
    echo "Unable to get Debian version info"
    exit 4
}

VERSION=`cat "$ROOTFS/etc/wb-fw-version"` || {
	echo "Unable to get firmware version"
	exit 4
}

if [[ -n "${FIT_IMAGE_DTB}" ]] ; then
    echo "Use special board-defined DTB for FIT image: ${FIT_IMAGE_DTB}"
    DTB_NAME="${FIT_IMAGE_DTB}"
else
    DTB_NAME=$(sed -n 's/^fdt_file=\/boot\/dtbs\///p' "$ROOTFS/boot/uEnv.txt")
fi

echo "Board:       $BOARD"
echo "RootFS:      $ROOTFS"
echo "DTB name:    $DTB_NAME"
echo "FW version:  $VERSION"
echo "Debian:      $VERSION_CODENAME"
echo "Release:     $RELEASE_NAME"
echo "Suite:       $SUITE"
echo "Target:      $TARGET"
echo "Repo prefix: $REPO_PREFIX"

if [ ! -z "$2" ]; then
    VERSION=$2
    echo "FW version overriden: $VERSION"
fi

FULL_VERSION="${VERSION}_${SUITE}"
if [[ -n "$REPO_PREFIX" ]]; then
    FULL_VERSION="${FULL_VERSION}_$(echo $REPO_PREFIX | sed -e 's/\W/+/g' -e 's/_/+/g')"
fi

OUT_DIR=${OUT_DIR:-"${IMAGES_DIR}/${VERSION}"}
mkdir -p ${OUT_DIR}
IMG_NAME="${OUT_DIR}/${FULL_VERSION}_emmc_wb${BOARD}.img"
WEBUPD_NAME="${OUT_DIR}/${FULL_VERSION}_webupd_wb${BOARD}.fit"

if  [ -n "$MAKE_IMG" ]; then
    echo "Create IMG"
    rm -f ${IMG_NAME}

    if [[ -n "$U_BOOT_ROOTFS" ]] && [[ -e "${ROOTFS}/${U_BOOT_ROOTFS}" ]]; then
        echo "Use u-boot from rootfs"
        U_BOOT_PATH="${ROOTFS}/${U_BOOT_ROOTFS}"
    else
        echo "Use default u-boot"
        U_BOOT_PATH="${TOP_DIR}/${U_BOOT}"
    fi

    $TOP_DIR/image/create_image.sh ${IMAGE_TYPE} ${ROOTFS} ${U_BOOT_PATH} ${IMG_NAME}
    zip -j ${IMG_NAME}.zip ${IMG_NAME}
fi

# try to load zImage from contribs
ZIMAGE_DEFAULT_PATH="${SCRIPT_DIR}/../contrib/usbupdate/zImage.$KERNEL_FLAVOUR"
mkdir -p "$(dirname "$ZIMAGE_DEFAULT_PATH")"

ZIMAGE="$(readlink -f "$ZIMAGE_DEFAULT_PATH" || true)"
if [[ ! -f $ZIMAGE ]]; then
    echo "Local zImage not found, downloading one to $ZIMAGE_DEFAULT_PATH"
    ZIMAGE_URL="http://fw-releases.wirenboard.com/utils/build-image/zImage.$KERNEL_FLAVOUR"
    wget -O "$ZIMAGE_DEFAULT_PATH" "$ZIMAGE_URL"
    ZIMAGE="$(readlink -f "$ZIMAGE_DEFAULT_PATH")"
fi

if [[ ! -f "$ZIMAGE" ]]; then
    echo "Failed to find zImage even after downloading, something went wrong"
    exit 1
fi

# try to load DTB from contribs
DTB_DEFAULT_PATH="${SCRIPT_DIR}/../contrib/usbupdate/dtbs/$KERNEL_FLAVOUR/$DTB_NAME"
mkdir -p "$(dirname "$DTB_DEFAULT_PATH")"

DTB="$(readlink -f "$DTB_DEFAULT_PATH")"
if [[ ! -e "$DTB" ]]; then
    echo "Local DTB not found, downloading one to $DTB_DEFAULT_PATH"
    DTB_URL="http://fw-releases.wirenboard.com/utils/build-image/dtbs/$KERNEL_FLAVOUR/$DTB_NAME"
    wget -O "$DTB_DEFAULT_PATH" "$DTB_URL"
    DTB="$(readlink -f "$DTB_DEFAULT_PATH")"
fi

if [[ ! -e "$DTB" ]]; then
    echo "Failed to find DTB even after downloading, something went wrong"
    exit 1
fi

echo "Using zImage from $ZIMAGE"
"$TOP_DIR/image/create_update.sh" "$ROOTFS" "$ZIMAGE" "$DTB" "$WEBUPD_NAME"

echo "Done"
echo  ${OUT_DIR}
