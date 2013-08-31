#!/bin/bash

ADD_PACKAGES="netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,wireless-tools,usbutils"
REPO="http://ftp.debian.org/debian"
OUTPUT="rootfs"
RELEASE=wheezy

echo "Install dependencies"
apt-get install qemu-user-static binfmt-support

echo "Will create rootfs"
debootstrap --include=${ADD_PACKAGES} --verbose --arch armel --variant=minbase --foreign ${RELEASE} ${OUTPUT} ${REPO}

echo "Copy qemu to rootfs"
cp /usr/bin/qemu-arm-static ${OUTPUT}/usr/bin

modprobe binfmt_misc
mkdir ${OUTPUT}/dev/pts
mount -t devpts devpts ${OUTPUT}/dev/pts
mount -t proc proc ${OUTPUT}/proc

sudo chroot ${OUTPUT} /debootstrap/debootstrap --second-stage
