#!/bin/bash

ADD_PACKAGES="netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,wireless-tools,usbutils,i2c-tools,isc-dhcp-client,wpasupplicant"
REPO="http://ftp.debian.org/debian"
OUTPUT="rootfs"
RELEASE=wheezy


if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you are not root."
	echo "USAGE: sudo create_rootfs.sh"
	exit 1
fi

# directly download firmware-realtek from non-free repo
RTL_FIRMWARE_DEB="http://ftp.de.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-realtek_0.36+wheezy.1_all.deb"


echo "Install dependencies"
apt-get install qemu-user-static binfmt-support

echo "Will create rootfs"
debootstrap --include=${ADD_PACKAGES} --verbose --arch armel  --variant=minbase --foreign ${RELEASE} ${OUTPUT} ${REPO}

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

echo "Setup additional packages"
chroot ${OUTPUT}/ apt-get -y install hostapd python3-minimal unzip minicom gpsd iw



#echo "Add rtl8188 hostapd package"
#RTL8188_DEB=hostapd_1.1-rtl8188_armel.deb
#cp ../contrib/rtl8188_hostapd/${RTL8188_DEB} ${OUTPUT}/
#chroot ${OUTPUT}/ dpkg -i ${RTL8188_DEB}
#chroot ${OUTPUT}/ rm ${RTL8188_DEB}

echo "Add libnfc packages"
mkdir ${OUTPUT}/tmp/libnfc
cp ../contrib/libnfc/libnfc*.deb ${OUTPUT}/tmp/libnfc
chroot ${OUTPUT}/ dpkg -i /tmp/libnfc/libnfc5_1.7.0-2_armel.deb /tmp/libnfc/libnfc-bin_1.7.0-2_armel.deb /tmp/libnfc/libnfc-examples_1.7.0-2_armel.deb
rm -r ${OUTPUT}/tmp/libnfc



echo "Install realtek firmware"
chroot ${OUTPUT}/ wget ${RTL_FIRMWARE_DEB} -O rtl_firmware.deb
chroot ${OUTPUT}/ dpkg -i rtl_firmware.deb
chroot ${OUTPUT}/ rm rtl_firmware.deb

echo "Overwrite configs one more time"
cp -r configs/* ${OUTPUT}/

echo "Copy utils, examples to opt folder"
cp -r ../utils ${OUTPUT}/opt/
cp -r ../examples ${OUTPUT}/opt/


echo "Install quick2wire"
ORIG_DIR=`pwd`
cd ${OUTPUT}/opt/
wget https://github.com/quick2wire/quick2wire-python-api/archive/master.zip
unzip master.zip
cd ${ORIG_DIR}

echo "export PYTHONPATH=/opt/quick2wire-python-api-master/" >> ${OUTPUT}/root/.bashrc

echo "Umount proc,dev,dev/pts in rootfs"
umount ${OUTPUT}/proc
umount ${OUTPUT}/dev/pts
umount ${OUTPUT}/dev
#umount ${OUTPUT}/sys
