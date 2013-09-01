#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you are not root."
	echo "USAGE: sudo create_rootfs.sh"
	exit 1
fi


ADD_PACKAGES="netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,wireless-tools,usbutils,i2c-tools,isc-dhcp-client,firmware-realtek,wpasupplicant"
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

echo "Second debootstrap stage"
sudo chroot ${OUTPUT} /debootstrap/debootstrap --second-stage

echo "Set root password"
sudo chroot ${OUTPUT}/ /bin/sh -c "echo root:wirenboard | chpasswd"

echo "Overwrite configs"
cp -r configs/* ${OUTPUT}/


echo "Update apt"
sudo chroot ${OUTPUT}/ apt-get update

echo "Setup locales"
chroot ${OUTPUT}/ apt-get -y install apt-utils dialog locales

chroot ${OUTPUT}/ sed -i "s/^# en_US/en_US/" /etc/locale.gen
chroot ${OUTPUT}/ /usr/sbin/locale-gen
LANG=en_US.UTF-8 sudo chroot ${OUTPUT}/ update-locale


echo "Add rtl8188 hostapd package"
RTL8188_DEB=rtl8188_hostapd/hostapd_1.1-rtl8188_armel.deb
cp ../contrib/${RTL8188_DEB} ${OUTPUT}/
chroot ${OUTPUT}/ dpkg -i ${RTL8188_DEB}
chroot ${OUTPUT}/ rm ${RTL8188_DEB}




