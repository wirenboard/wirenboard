#!/bin/bash
ADD_PACKAGES="netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,wireless-tools,usbutils,i2c-tools,udhcpc,wpasupplicant,psmisc,curl,dnsmasq,gammu,python-serial"
REPO="http://ftp.debian.org/debian"
OUTPUT="rootfs"
RELEASE=wheezy

if [ $# -ne 2 ]
then
  echo "USAGE: $1 <path to rootfs> <BOARD>"
  exit 1
fi

OUTPUT=$1
BOARD=$2

if [ -e "$OUTPUT" ]; then
    echo "output rootfs folder $OUTPUT already exists, exiting"
    exit 2;
fi


mkdir -p $OUTPUT



if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you are not root."
	echo "USAGE: sudo create_rootfs.sh"
	exit 1
fi

# directly download firmware-realtek from jessie non-free repo
RTL_FIRMWARE_DEB="http://ftp.de.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-realtek_0.43_all.deb"

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

echo "Install initial repos"
sudo cp ../configs/configs/etc/apt/sources.list ${OUTPUT}/etc/apt

echo "Overwrite configs"
sudo chroot ${OUTPUT}/ apt-get -o Dpkg::Options::="--force-overwrite" install wb-configs
sudo chroot ${OUTPUT}/ locale-gen



echo "Update&upgrade apt"
sudo chroot ${OUTPUT}/ apt-get update
sudo chroot ${OUTPUT}/ apt-get -y upgrade

echo "Setup locales"
chroot ${OUTPUT}/ apt-get -y install apt-utils dialog locales

cp configs/etc/locale.gen ${OUTPUT}/etc/locale.gen
chroot ${OUTPUT}/ /usr/sbin/locale-gen
LANG=en_US.UTF-8 sudo chroot ${OUTPUT}/ update-locale

echo "Setup additional packages"
chroot ${OUTPUT}/ apt-get -y install  python3-minimal unzip minicom iw ppp libmodbus5



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
chroot ${OUTPUT}/  apt-get -o Dpkg::Options::="--force-overwrite" -o Dpkg::Options::="--force-confnew"  install wb-configs



echo "Install quick2wire"
ORIG_DIR=`pwd`
cd ${OUTPUT}/opt/
wget https://github.com/quick2wire/quick2wire-python-api/archive/master.zip
unzip master.zip
cd ${ORIG_DIR}

#~ echo "export PYTHONPATH=/opt/quick2wire-python-api-master/" >> ${OUTPUT}/root/.bashrc

echo "Install public key for contactless repo"
chroot ${OUTPUT}/ apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
chroot ${OUTPUT}/ apt-get update


echo "Install packages from contactless repo"
chroot ${OUTPUT}/ apt-get -y install cmux hubpower python-wb-io modbus-utils wb-utils
chroot ${OUTPUT}/ apt-get -y install libnfc5 libnfc-bin libnfc-examples libnfc-pn53x-examples

# mqtt
chroot ${OUTPUT}/ apt-get -y install libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients python-mosquitto

# todo: should be in dependencies
chroot ${OUTPUT}/ apt-get -y install  libjsoncpp0


# kernel
chroot ${OUTPUT}/ apt-get -y install linux-latest


chroot ${OUTPUT}/ apt-get -y install  openssl ca-certificates

chroot ${OUTPUT}/ apt-get -y install  mqtt-wss webfs wb-homa-webinterface

case "$BOARD" in
    "32" )
        # WB Smart Home specific
        FORCE_WB_VERSION=32 chroot ${OUTPUT}/ apt-get -y install  wb-homa-drivers  wb-homa-ism-radio
        chroot ${OUTPUT}/ apt-get -y install netplug hostapd

        echo "fdt_file=/boot/dtbs/imx23-wirenboard32.dtb" > ${OUTPUT}/boot/uEnv.txt

    ;;
    "28" )

        echo "fdt_file=/boot/dtbs/imx23-wirenboard28.dtb" >  ${OUTPUT}/boot/uEnv.txt

    ;;

    "KMON1" )
        # MKA3
        FORCE_WB_VERSION=KMON1 chroot ${OUTPUT}/ apt-get -y install wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent
        chroot ${OUTPUT}/ apt-get -y install wb-dbic

        # https://github.com/contactless/wb-dbic
        cp ../../wb-dbic/set_confidential.sh ${OUTPUT}/
        chroot ${OUTPUT}/ /set_confidential.sh
        rm ${OUTPUT}/set_confidential.sh


        echo "fdt_file=/boot/dtbs/imx23-wirenboard-kmon1.dtb" > ${OUTPUT}/boot/uEnv.txt

    ;;

esac







chroot ${OUTPUT}/ apt-get clean

echo "Umount proc,dev,dev/pts in rootfs"
umount ${OUTPUT}/proc
umount ${OUTPUT}/dev/pts
umount ${OUTPUT}/dev
#umount ${OUTPUT}/sys
