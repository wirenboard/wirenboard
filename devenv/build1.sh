#!/bin/bash
set -u -e
cd /root

export LC_ALL=C LANGUAGE=C LANG=C

DEBOOTSTRAP_DIR=$TARGET_ROOTFS/debootstrap  debootstrap --second-stage --second-stage-target=$TARGET_ROOTFS

chroot $TARGET_ROOTFS  /bin/bash -e<<EOF
apt install -y python-netaddr python-pyparsing liblircclient-dev libusb-dev libusb-1.0-0-dev jq python-dev python-smbus
apt install -y libusb-dev libusb-1.0-0-dev jq python-dev python-smbus
apt install -y python-setuptools python3-setuptools liblog4cpp5-dev libpng-dev libqt4-dev bc lzop bison flex kmod
apt install -y binfmt-support node-rimraf
apt-get install -y proot git
EOF




do_build() {
	export RELEASE=$1 ARCH=$2 BOARD=$3
#	export ROOTFS="/rootfs/$RELEASE-$ARCH"
#	time /root/rootfs/create_rootfs.sh $BOARD
#	rm -f /root/output/rootfs_base_${ARCH}.tar.gz
#	/root/prep.sh
}

do_build stretch armhf 6x

