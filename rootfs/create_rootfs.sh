#!/bin/bash

ADD_PACKAGES="netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,wireless-tools,usbutils,i2c-tools,udhcpc,wpasupplicant,netplug,psmisc,curl,dnsmasq"
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
chroot ${OUTPUT}/ apt-get -y install hostapd python3-minimal unzip minicom iw ppp libmodbus5



#echo "Add rtl8188 hostapd package"
#RTL8188_DEB=hostapd_1.1-rtl8188_armel.deb
#cp ../contrib/rtl8188_hostapd/${RTL8188_DEB} ${OUTPUT}/
#chroot ${OUTPUT}/ dpkg -i ${RTL8188_DEB}
#chroot ${OUTPUT}/ rm ${RTL8188_DEB}



echo "Install realtek firmware"
chroot ${OUTPUT}/ wget ${RTL_FIRMWARE_DEB} -O rtl_firmware.deb
chroot ${OUTPUT}/ dpkg -i rtl_firmware.deb
chroot ${OUTPUT}/ rm rtl_firmware.deb

echo "Overwrite configs one more time"
cp -r configs/* ${OUTPUT}/

echo "Copy utils, examples to opt folder"
#~ cp -r ../utils ${OUTPUT}/opt/
cp -r ../examples ${OUTPUT}/opt/


echo "Install quick2wire"
ORIG_DIR=`pwd`
cd ${OUTPUT}/opt/
wget https://github.com/quick2wire/quick2wire-python-api/archive/master.zip
unzip master.zip
cd ${ORIG_DIR}

#~ echo "export PYTHONPATH=/opt/quick2wire-python-api-master/" >> ${OUTPUT}/root/.bashrc


echo "Install cmux"
wget https://github.com/contactless/cmux/releases/download/0.3/cmux -O ${OUTPUT}/opt/utils/gsm/cmux
chmod a+x ${OUTPUT}/opt/utils/gsm/cmux

echo "Install public key for contactless repo"
chroot ${OUTPUT}/ apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
chroot ${OUTPUT}/ apt-get update


echo "Install packages from contactless repo"
chroot ${OUTPUT}/ apt-get install hubpower python-wb-io modbus-utils wb-utils
chroot ${OUTPUT}/ apt-get install libnfc5 libnfc-bin libnfc-examples

# mqtt
chroot ${OUTPUT}/ apt-get install libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients

# todo: should be in dependencies
chroot ${OUTPUT}/ apt-get install  libjsoncpp0

echo "Umount proc,dev,dev/pts in rootfs"
umount ${OUTPUT}/proc
umount ${OUTPUT}/dev/pts
umount ${OUTPUT}/dev
#umount ${OUTPUT}/sys
