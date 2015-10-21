#!/bin/bash
set -e
set -x
ADD_PACKAGES=netbase,ifupdown,iproute,openssh-server,iputils-ping,wget,udev,\
net-tools,ntpdate,ntp,vim,nano,less,tzdata,console-tools,module-init-tools,mc,\
wireless-tools,usbutils,i2c-tools,udhcpc,wpasupplicant,psmisc,curl,dnsmasq,gammu,\
python-serial,memtester,apt-utils,dialog,locales,python3-minimal,unzip,minicom,\
iw,ppp,libmodbus5,python-smbus,ssmtp
#REPO="http://ftp.debian.org/debian"
REPO="http://mirror.yandex.ru/debian"
OUTPUT="rootfs"
RELEASE=wheezy

# directly download firmware-realtek from jessie non-free repo
RTL_FIRMWARE_DEB="http://ftp.de.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-realtek_0.43_all.deb"

if [ $# -ne 2 ]
then
  echo "USAGE: $0 <path to rootfs> <BOARD>"
  exit 1
fi

case "$2" in
    4|32|28|MKA3|NETMON)
        ;;
    *)
        echo "Unknown board"
        ;;
esac

[[ -n "$__unshared" ]] || {
	[[ $EUID == 0 ]] || {
		exec sudo -E "$0" "$@"
	}

	# Jump into separate namespace
	export __unshared=1
	exec unshare -umi "$0" "$@"
}

OUTPUT=$1
BOARD=$2

if [ -e "$OUTPUT" ]; then
    echo "output rootfs folder $OUTPUT already exists, exiting"
    exit 2;
fi

mkdir -p $OUTPUT

export LC_ALL=C
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONFIG_DIR="$SCRIPT_DIR/../configs/configs"

DEBOOTSTRAP_SRC_TARBALL="$(readlink -f ${OUTPUT}/../debootstrap_src.tgz)"

# a few shortcuts
chr() {
    chroot ${OUTPUT} "$@"
}

chr_nofail() {
    chroot ${OUTPUT} "$@" || true
}

chr_apt() {
    chr apt-get install -y "$@"
}

dbg() {
    chr ls -l /dev/pts
    chr ls -l /proc
}


echo "Install dependencies"
apt-get install qemu-user-static binfmt-support || true

DEBOOTSTRAP_ARGS="
	--include=${ADD_PACKAGES}
	--verbose
	--arch armel
	--variant=minbase
	${RELEASE} ${OUTPUT} ${REPO}
"

[[ -e "$DEBOOTSTRAP_SRC_TARBALL" ]] || {
	echo "No $DEBOOTSTRAP_SRC_TARBALL found, will create one for later use"
	debootstrap --make-tarball=$DEBOOTSTRAP_SRC_TARBALL $DEBOOTSTRAP_ARGS
}

echo "Will create rootfs"
debootstrap --unpack-tarball=$DEBOOTSTRAP_SRC_TARBALL --foreign $DEBOOTSTRAP_ARGS

echo "Copy qemu to rootfs"
cp /usr/bin/qemu-arm-static ${OUTPUT}/usr/bin ||
cp /usr/bin/qemu-arm ${OUTPUT}/usr/bin
modprobe binfmt_misc

echo "Second debootstrap stage"
chr /debootstrap/debootstrap --second-stage

# without devpts mount options you will likely end up looking why you can't open
# new terminal window :)
echo "Mount /proc, /sys, /dev, /dev/pts"
mkdir -p ${OUTPUT}/{proc,sys,dev/pts}
mount --bind /proc ${OUTPUT}/proc
mount --bind /sys ${OUTPUT}/sys
mount -t devpts devpts ${OUTPUT}/dev/pts -o "gid=5,mode=666,ptmxmode=0666,newinstance"
rm -f ${OUTPUT}/dev/ptmx
ln -s /dev/pts/ptmx ${OUTPUT}/dev/ptmx
if [[ ! -L ${OUTPUT}/dev/ptmx ]]; then
    if [[ -e ${OUTPUT}/dev/ptmx ]]; then
        mount --bind ${OUTPUT}/dev/pts/ptmx ${OUTPUT}/dev/ptmx
    else
        ln -s /dev/pts/ptmx ${OUTPUT}/dev/ptmx
    fi
fi

cleanup() {
    local ret=$?

    echo "Umount proc,dev,dev/pts in rootfs"
    [[ -L ${OUTPUT}/dev/ptmx ]] || umount ${OUTPUT}/dev/ptmx
    umount ${OUTPUT}/dev/pts
    umount ${OUTPUT}/proc
    umount ${OUTPUT}/sys

    rm -f ${OUTPUT}/usr/sbin/policy-rc.d

    return $ret
}
trap cleanup EXIT

# This disables startin services when installing packages
echo exit 101 > ${OUTPUT}/usr/sbin/policy-rc.d
chmod +x ${OUTPUT}/usr/sbin/policy-rc.d

echo "Set root password"
chr /bin/sh -c "echo root:wirenboard | chpasswd"

echo "Install initial repos"
cp ${CONFIG_DIR}/etc/apt/sources.list.d/contactless.list ${OUTPUT}/etc/apt/sources.list.d/
#echo "deb [arch=armel,all] http://lexs.blasux.ru/ repos/debian/contactless/" > $OUTPUT/etc/apt/sources.list.d/local.list
cp ${CONFIG_DIR}/etc/gai.conf.wb ${OUTPUT}/etc/gai.conf     # workaround for IPv6 lags

echo "Install public key for contactless repo"
chr apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869

echo "Update&upgrade apt"
chr apt-get update
chr apt-get -y upgrade

echo "Setup locales"
cp ${CONFIG_DIR}/etc/locale.gen.wb ${OUTPUT}/etc/locale.gen
chr /usr/sbin/locale-gen
chr update-locale

echo "Install realtek firmware"
wget ${RTL_FIRMWARE_DEB} -O ${OUTPUT}/rtl_firmware.deb
chr dpkg -i rtl_firmware.deb
rm ${OUTPUT}/rtl_firmware.deb

echo "Install quick2wire"
pushd ${OUTPUT}/opt/
wget https://github.com/quick2wire/quick2wire-python-api/archive/master.zip -O master.zip
unzip master.zip
popd

#~ echo "export PYTHONPATH=/opt/quick2wire-python-api-master/" >> ${OUTPUT}/root/.bashrc

echo "Install packages from contactless repo"
pkgs="cmux hubpower python-wb-io modbus-utils wb-configs serial-tool busybox-syslogd"
pkgs+=" libnfc5 libnfc-bin libnfc-examples libnfc-pn53x-examples"

# mqtt
pkgs+=" libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients python-mosquitto"

pkgs+=" openssl ca-certificates"
chr_apt --force-yes $pkgs

# stop mosquitto on host
service mosquitto stop || /bin/true

chr /etc/init.d/mosquitto start
chr_apt --force-yes linux-latest wb-mqtt-homeui wb-mqtt-confed
chr /etc/init.d/mosquitto stop


#echo "Add mosquitto package"
#MOSQ_DEB=mosquitto_1.3.4-2contactless1_armel.deb
#cp ${SCRIPT_DIR}/../contrib/deb/mosquitto/${MOSQ_DEB} ${OUTPUT}/
#chr dpkg -i ${MOSQ_DEB}
#rm ${OUTPUT}/${MOSQ_DEB}

set_fdt() {
    echo "fdt_file=/boot/dtbs/${1}.dtb" > ${OUTPUT}/boot/uEnv.txt
}

case "$BOARD" in
    "4" )
        # Wiren Board 4
        FORCE_WB_VERSION=41 chr_apt wb-homa-ism-radio wb-homa-modbus wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system netplug

        echo "Add rtl8188 hostapd package"
        RTL8188_DEB=hostapd_1.1-rtl8188_armel.deb
        cp ${SCRIPT_DIR}/../contrib/rtl8188_hostapd/${RTL8188_DEB} ${OUTPUT}/
        chr_nofail dpkg -i ${RTL8188_DEB}
        rm ${OUTPUT}/${RTL8188_DEB}

        set_fdt imx23-wirenboard41
    ;;

    "CQC10" )
        # CQC10 device
        FORCE_WB_VERSION=CQC10 chr_apt wb-homa-w1 wb-homa-gpio wb-rules wb-mqtt-spl-meter

        echo "Add wb-mqtt-tcs34725 package"

        TCS_DEB=/home/boger/work/board/cinema/wb-mqtt-tcs34725_1.0_all.deb
        cp TCS_DEB ${OUTPUT}/
        chr_nofail dpkg -i `basename ${TCS_DEB}`
        rm ${OUTPUT}/`basename ${TCS_DEB}`

        set_fdt imx23-wirenboard-cqc10

    ;;
    "32" )
        # WB Smart Home specific
        FORCE_WB_VERSION=32 chr_apt wb-homa-ism-radio wb-homa-modbus wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system

        chr_apt netplug hostapd

        set_fdt imx23-wirenboard32
    ;;

    "28" )
        set_fdt imx23-wirenboard28
    ;;

    "MKA3" )
        # MKA3
        FORCE_WB_VERSION=KMON1 chr_apt wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent
        FORCE_WB_VERSION=KMON1 chr_apt wb-dbic

        # https://github.com/contactless/wb-dbic
        cp ${SCRIPT_DIR}/../../wb-dbic/set_confidential.sh ${OUTPUT}/
        chr /set_confidential.sh
        rm ${OUTPUT}/set_confidential.sh

        set_fdt imx23-wirenboard-kmon1
    ;;


    "NETMON" )
        # NETMON-1
        FORCE_WB_VERSION=KMON1 chr_apt wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent wb-homa-modbus wb-rules

        chr_apt netplug

        set_fdt imx23-wirenboard-kmon1.dtb
    ;;
esac

chr apt-get clean
rm -rf ${OUTPUT}/run/* ${OUTPUT}/var/cache/apt/* ${OUTPUT}/var/lib/apt/lists/*

# removing SSH host keys
rm -f ${OUTPUT}/etc/ssh/ssh_host_* || /bin/true

# (re-)start mosquitto on host
service mosquitto start || /bin/true

exit 0
