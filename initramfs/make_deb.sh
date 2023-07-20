#!/bin/bash

set -e

PLATFORM=$1
PACKAGES="dropbear mmc-utils rsync dosfstools fdisk kbd"

if [ -z "$PLATFORM" ]; then
    echo "Usage: $0 6x/7x"
    exit 1
fi

echo "Installing build deps"
if ! which fpm || ! which dumpimage; then
    apt-get update && apt-get install -y ruby-rubygems u-boot-tools
    gem install fpm
fi

TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading latest FIT for platform wb$PLATFORM..."
FIT_FILE="$TMP_DIR/latest.fit"
wget -O "$FIT_FILE" "http://fw-releases.wirenboard.com/fit_image/stable/${PLATFORM}/latest.fit"

echo "Gathering rootfs from FIT..."
ROOTFS_FILE="$TMP_DIR/rootfs.tar.gz"
dumpimage -T flat_dt -p 3 -o "$ROOTFS_FILE" "$FIT_FILE"

echo "Unpacking rootfs..."
ROOTFS_DIR="$TMP_DIR/rootfs"
mkdir "$ROOTFS_DIR"
tar -xf "$ROOTFS_FILE" -C "$ROOTFS_DIR"

echo "Chrooting into rootfs in order to install more packages..."
"$ROOTFS_DIR"/chroot_this.sh sh -c "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y $PACKAGES"
FW_VERSION=$(cat "$ROOTFS_DIR"/etc/wb-fw-version)

echo "Creating initramfs directory..."
INITRAMFS_DIR="$TMP_DIR/initramfs"
mkdir "$INITRAMFS_DIR"
./create_initramfs.sh "$ROOTFS_DIR" "$INITRAMFS_DIR" "wb$PLATFORM"

echo "Archiving initramfs..."
INITRAMFS_FILE="$TMP_DIR/initramfs.tar.gz"
tar -czf "$INITRAMFS_FILE" -C "$INITRAMFS_DIR" .

echo "Creating deb package..."
DEB_DIR="$TMP_DIR/deb"
mkdir -p "$DEB_DIR/usr/share/wb-initramfs"
cp "$INITRAMFS_FILE" "$DEB_DIR/usr/share/wb-initramfs/initramfs-wb${PLATFORM}.tar.gz"
cp -r "$ROOTFS_DIR"/etc/wb-fw-version "$DEB_DIR/usr/share/wb-initramfs/wb-fw-version.wb${PLATFORM}"

fpm -s dir -t deb -n "wb-initramfs-wb$PLATFORM" -v "1.0.0-$FW_VERSION" \
    --architecture all \
    --description "Wiren Board initramfs image (wb${PLATFORM})" \
    --maintainer "Wiren Board team <info@wirenboard.com>" \
    --url "https://github.com/wirenboard/wirenboard" \
    -C "$DEB_DIR" .
