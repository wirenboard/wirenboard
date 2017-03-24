#!/bin/bash
set -e
#set -x


#REPO="http://ftp.debian.org/debian"
REPO="http://mirror.yandex.ru/debian/"
OUTPUT="rootfs"
RELEASE=${RELEASE:-wheezy}
ARCH=${ARCH:-armel}

ADD_REPO_FILE=$OUTPUT/etc/apt/sources.list.d/additional.list

# directly download firmware-realtek from jessie non-free repo
RTL_FIRMWARE_DEB="http://ftp.de.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-realtek_0.43_all.deb"

if [[ ( "$#" < 2)  ]]
then
  echo "USAGE: $0 <path to rootfs> <BOARD> [list of additional repos]"
  echo ""
  echo "How to attach additional repos:"
  echo -e "\t$0 <path to rootfs> <BOARD> \"http://localhost:8086/\""
  echo -e "Additional repo must have a public key file on http://<hostname>/repo.gpg.key"
  echo -e "In process, repo names will be expanded as \"deb <repo_address> testing main\""
  exit 1
fi

case "$2" in
    5|55|55P|58|55-ZERO|58-ZERO|4|32|28|MKA3|MKA31|NETMON|CQC10|AC-E1)
        ;;
    *)
        echo "Unknown board" 
        exit 1
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

die() {
	local ret=$?
	>&2 echo "!!! $@"
	[[ $ret == 0 ]] && exit 1 || exit $ret
}

# Runs jq with given arguments and replaces the original file with result
# Example: json_edit '.foo = 123'
json_edit() {
    [[ -e "$JSON" ]] || {
        die "JSON file '$JSON' not found"
        return 1
    }

    local tmp=`mktemp`
    sed 's#//.*##' "$JSON" |    # there are // comments, strip them out
    jq "$@" > "$tmp"
    local ret=$?
    [[ "$ret" == 0 ]] && cat "$tmp" > "$JSON"
    rm "$tmp"
    return $ret
}

[[ -e "$OUTPUT" ]] && die "output rootfs folder $OUTPUT already exists, exiting"

mkdir -p $OUTPUT

export LC_ALL=C
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

ROOTFS_BASE_TARBALL="$(dirname ${OUTPUT})/rootfs_base.tar.gz"

ROOTFS_DIR=${OUTPUT}
. "${SCRIPT_DIR}"/rootfs_env.sh

chr_install_deb() {
    DEB_FILE="$1"
    cp ${DEB_FILE} ${OUTPUT}/
    chr_nofail dpkg -i `basename ${DEB_FILE}`
    rm ${OUTPUT}/`basename ${DEB_FILE}`
}

setup_additional_repos() {
    # setup additional repos

    mkdir -p `dirname $ADD_REPO_FILE`
    touch $ADD_REPO_FILE
    for repo in "${@}"; do
        echo "=> Setup additional repository $repo..."
        echo "deb $repo testing main" >> $ADD_REPO_FILE
        chr bash -c "wget $repo/repo.gpg.key -O- | apt-key add -"
    done
}

echo "Install dependencies"
apt-get install -y qemu-user-static binfmt-support || true

if [[ -e "$ROOTFS_BASE_TARBALL" ]]; then
	echo "Using existing $ROOTFS_BASE_TARBALL"
	rm -rf $OUTPUT
	mkdir -p $OUTPUT
	tar xpf $ROOTFS_BASE_TARBALL -C ${OUTPUT}

	prepare_chroot
	services_disable

    # setup additional repositories
    echo "Install additional repos"
    setup_additional_repos "${@:3}"

	echo "Updating"
	chr apt-get update
	chr apt-get -y upgrade
else
	echo "No $ROOTFS_BASE_TARBALL found, will create one for later use"
	#~ exit
	debootstrap \
		--foreign \
		--verbose \
		--arch $ARCH \
		--variant=minbase \
		${RELEASE} ${OUTPUT} ${REPO}

	echo "Copy qemu to rootfs"
	cp /usr/bin/qemu-arm-static ${OUTPUT}/usr/bin ||
	cp /usr/bin/qemu-arm ${OUTPUT}/usr/bin
	modprobe binfmt_misc || true

	# kludge to fix ssmtp configure that breaks when FQDN is unknown
	echo "127.0.0.1       wirenboard localhost" > ${OUTPUT}/etc/hosts
	echo "::1     localhost ip6-localhost ip6-loopback" >> ${OUTPUT}/etc/hosts
	echo "fe00::0     ip6-localnet" >> ${OUTPUT}/etc/hosts
	echo "ff00::0     ip6-mcastprefix" >> ${OUTPUT}/etc/hosts
	echo "ff02::1     ip6-allnodes" >> ${OUTPUT}/etc/hosts
	echo "ff02::2     ip6-allrouters" >> ${OUTPUT}/etc/hosts
	echo "127.0.0.2 $(hostname)" >> ${OUTPUT}/etc/hosts

    echo "Delete unused locales"
    /bin/sh -c "find ${OUTPUT}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'ru*' | xargs rm -r"

    mkdir -p ${OUTPUT}/etc/dpkg/dpkg.cfg.d/

    /bin/cat <<EOM > ${OUTPUT}/etc/dpkg/dpkg.cfg.d/01_nodoc
path-exclude /usr/share/locale/*
path-include /usr/share/locale/en*
path-include /usr/share/locale/ru*
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOM


	echo "Second debootstrap stage"
	chr /debootstrap/debootstrap --second-stage


	prepare_chroot
	services_disable

	echo "Set root password"
	chr /bin/sh -c "echo root:wirenboard | chpasswd"

        echo "Install primary sources.list"
        echo "deb ${REPO} ${RELEASE} main" >${OUTPUT}/etc/apt/sources.list
        echo "deb ${REPO} ${RELEASE}-updates main" >>${OUTPUT}/etc/apt/sources.list
        echo "deb http://security.debian.org ${RELEASE}/updates main" >>${OUTPUT}/etc/apt/sources.list

	echo "Install initial repos"
	#echo "deb [arch=${ARCH},all] http://lexs.blasux.ru/ repos/debian/contactless/" > $OUTPUT/etc/apt/sources.list.d/local.list
	echo "deb http://releases.contactless.ru/ ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/contactless.list
	echo "deb http://http.debian.net/debian ${RELEASE}-backports main" > ${OUTPUT}/etc/apt/sources.list.d/${RELEASE}-backports.list
	echo "precedence ::ffff:0:0/96  100" > ${OUTPUT}/etc/gai.conf # workaround for IPv6 lags

	echo "Install public key for contactless repo"
	chr apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
    
    # setup additional repositories
    echo "Install additional repos"
    setup_additional_repos "${@:3}"

	echo "Update&upgrade apt"
	chr apt-get update
	chr apt-get -y --force-yes upgrade

	echo "Setup locales"
    chr_apt locales
	echo "en_GB.UTF-8 UTF-8" > ${OUTPUT}/etc/locale.gen
	echo "en_US.UTF-8 UTF-8" >> ${OUTPUT}/etc/locale.gen
	echo "ru_RU.UTF-8 UTF-8" >> ${OUTPUT}/etc/locale.gen
	chr /usr/sbin/locale-gen
	chr update-locale

    echo "Install additional packages"
    chr_apt --force-yes netbase ifupdown iproute openssh-server \
        iputils-ping wget udev net-tools ntpdate ntp vim nano less \
        tzdata console-tools module-init-tools mc wireless-tools usbutils \
        i2c-tools udhcpc wpasupplicant psmisc curl dnsmasq gammu \
        python-serial memtester apt-utils dialog locales \
        python3-minimal unzip minicom iw ppp libmodbus5 \
        python-smbus ssmtp moreutils

	echo "Install realtek firmware"
	wget ${RTL_FIRMWARE_DEB} -O ${OUTPUT}/rtl_firmware.deb
	chr dpkg -i rtl_firmware.deb
	rm ${OUTPUT}/rtl_firmware.deb

    WD="`pwd`"
	echo "Creating $ROOTFS_BASE_TARBALL"
	pushd ${OUTPUT}
	tar czpf $WD/$ROOTFS_BASE_TARBALL --one-file-system ./
	popd
fi

echo "Cleanup rootfs"
chr_nofail dpkg -r geoip-database


echo "Creating /mnt/data mountpoint"
mkdir ${OUTPUT}/mnt/data

echo "Install packages from contactless repo"
pkgs="cmux hubpower python-wb-io modbus-utils wb-configs serial-tool busybox-syslogd"
pkgs+=" libnfc5 libnfc-bin libnfc-examples libnfc-pn53x-examples"

# mqtt
pkgs+=" libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients python-mosquitto"

pkgs+=" openssl ca-certificates"

pkgs+=" avahi-daemon pps-tools"
chr mv /etc/apt/sources.list.d/contactless.list /etc/apt/sources.list.d/local.list
chr_apt --force-yes $pkgs
chr mv /etc/apt/sources.list.d/local.list /etc/apt/sources.list.d/contactless.list
# stop mosquitto on host
service mosquitto stop || /bin/true

chr /etc/init.d/mosquitto start
chr_apt --force-yes linux-headers-4.1.15-imxv5-x0.1 linux-image-4.1.15-imxv5-x0.1 linux-firmware-image-4.1.15-imxv5-x0.1 device-tree-compiler
chr_apt --force-yes wb-mqtt-confed

date '+%Y%m%d%H%M' > ${OUTPUT}/etc/wb-fw-version

set_fdt() {
    echo "fdt_file=/boot/dtbs/${1}.dtb" > ${OUTPUT}/boot/uEnv.txt
}

install_wb5_packages() {
    chr_apt wb-mqtt-homeui wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio \
    wb-homa-adc python-nrf24 wb-rules wb-rules-system netplug hostapd bluez can-utils \
    wb-test-suite wb-mqtt-lirc lirc-scripts wb-hwconf-manager wb-mqtt-dac
}

case "$BOARD" in
    "5" )
        # Wiren Board 5
        export FORCE_WB_VERSION=52
        install_wb5_packages
        set_fdt imx28-wirenboard52
    ;;

    "55" )
        # Wiren Board 5
        export FORCE_WB_VERSION=55
        install_wb5_packages
        set_fdt imx28-wirenboard55
    ;;

    "58" )
        # Wiren Board 5.8
        export FORCE_WB_VERSION=58
        install_wb5_packages
        set_fdt imx28-wirenboard58
    ;;

    "55P" )
        # Wiren Board 5 for Proton
        export FORCE_WB_VERSION=55
        chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-rules wb-rules-system netplug hostapd can-utils wb-test-suite wb-hwconf-manager wb-mqtt-dac

        set_fdt imx28-wirenboard55

        JSON=${OUTPUT}/etc/wb-hardware.conf
        json_edit '.slots|=map(if .id=="wb55-mod1" then .module="wbe-do-r6c-1" else . end)'
        json_edit '.slots|=map(if .id=="wb55-mod2" then .module="wbe-do-r6c-1" else . end)'
        json_edit '.slots|=map(if .id=="wb55-gsm" then .module="wb56-mod-rtc" else . end)'

    ;;

    "55-ZERO" )
        # Wiren Board Zero rev 5.5+
        export FORCE_WB_VERSION=55
        chr_apt wb-mqtt-homeui wb-homa-adc wb-rules wb-rules-system netplug wb-test-suite wb-hwconf-manager

        set_fdt imx28-wirenboard55

        JSON=${OUTPUT}/etc/wb-hardware.conf
        json_edit '.slots|=map(select(.id !="wb55-mod1"))'
        json_edit '.slots|=map(select(.id !="wb55-mod2"))'

        for extio_n in {1..8}; do
            json_edit '.slots|=map(select(.id !="wb5-extio'${extio_n}'"))'
        done

        json_edit '.slots|=map(if .id=="wb55-gsm" then .module="wb56-mod-rtc" else . end)'

    ;;

    "58-ZERO" )
        # Wiren Board Zero rev 5.8+
        export FORCE_WB_VERSION=58
        chr_apt wb-mqtt-homeui wb-homa-adc wb-rules wb-rules-system netplug wb-test-suite wb-hwconf-manager

        set_fdt imx28-wirenboard58

        JSON=${OUTPUT}/etc/wb-hardware.conf
        json_edit '.slots|=map(select(.id !="wb58-mod1"))'
        json_edit '.slots|=map(select(.id !="wb58-mod2"))'

        for extio_n in {1..8}; do
            json_edit '.slots|=map(select(.id !="wb5-extio'${extio_n}'"))'
        done

        json_edit '.slots|=map(if .id=="wb55-gsm" then .module="wb56-mod-rtc" else . end)'
        json_edit '.slots|=map(if .id=="wb5-eth" then .module="" else . end)'

        # disable 1-wire drivers to prevent floating pin from picking noise

        echo "blacklist w1_gpio" > ${OUTPUT}/etc/modprobe.d/wirenboard-zero-w1.conf
    ;;

    "4" )
        # Wiren Board 4
        export FORCE_WB_VERSION=41

        chr_apt wb-mqtt-homeui wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system netplug

        echo "Add rtl8188 hostapd package"

        RTL8188_DEB=hostapd_1.1-rtl8188_armel.deb
        chr_install_deb "${SCRIPT_DIR}/../contrib/rtl8188_hostapd/${RTL8188_DEB}"

        set_fdt imx23-wirenboard41
    ;;

    "CQC10" )
        # CQC10 device
        export FORCE_WB_VERSION=CQC10
        chr_apt wb-homa-w1 wb-homa-gpio wb-mqtt-spl-meter zabbix-agent wb-mqtt-homeui-mediamain

        echo "Add wb-mqtt-tcs34725 package"
        chr_install_deb /home/boger/work/board/cinema/wb-mqtt-tcs34725_1.1_all.deb
        echo "Add wb-techneva package"
        chr_install_deb /home/boger/work/board/cinema/wb-techneva/wb-techneva-cqc_1.1_all.deb

        set_fdt imx23-wirenboard-cqc10

    ;;
    "32" )
        # WB Smart Home specific
        export FORCE_WB_VERSION=32


        chr_apt wb-mqtt-homeui wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system

        chr_apt netplug hostapd

        set_fdt imx23-wirenboard32
    ;;

    "28" )
        export FORCE_WB_VERSION=28
        chr_apt wb-mqtt-homeui
        set_fdt imx23-wirenboard28
    ;;

    "MKA3" )
        # MKA3
        export FORCE_WB_VERSION=KMON1

        chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent wb-dbic

        # https://github.com/contactless/wb-dbic
        cp ${SCRIPT_DIR}/../../wb-dbic/set_confidential.sh ${OUTPUT}/
        chr /set_confidential.sh
        rm ${OUTPUT}/set_confidential.sh

        set_fdt imx23-wirenboard-kmon1
    ;;

    "MKA31" )
        # MKA31 based on WB52 (netmon2-1)
        export FORCE_WB_VERSION=52
        chr_apt wb-mqtt-homeui wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils wb-test-suite wb-hwconf-manager wb-mqtt-am2320 zabbix-agent

        cp ${SCRIPT_DIR}/../../wb-dbic/set_confidential.sh ${OUTPUT}/
        chr /set_confidential.sh
        rm ${OUTPUT}/set_confidential.sh

        set_fdt imx28-wirenboard52
    ;;

    "AC-E1" )
        export FORCE_WB_VERSION=28

        set_fdt imx23-wirenboard-ac-e1
    ;;

    "NETMON" )
        # NETMON-1
        export FORCE_WB_VERSION=KMON1
        chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent wb-mqtt-serial wb-rules

        chr_apt netplug

        set_fdt imx23-wirenboard-kmon1
    ;;
esac

chr /etc/init.d/mosquitto stop

# remove additional repo files
rm -rf $ADD_REPO_FILE
chr apt-get update

chr apt-get clean
rm -rf ${OUTPUT}/run/* ${OUTPUT}/var/cache/apt/archives/* ${OUTPUT}/var/lib/apt/lists/*

rm -f ${OUTPUT}/etc/apt/sources.list.d/local.list

# removing SSH host keys
rm -f ${OUTPUT}/etc/ssh/ssh_host_* || /bin/true

# reverting ssmtp kludge
sed "/$(hostname)/d" -i ${OUTPUT}/etc/hosts

# (re-)start mosquitto on host
service mosquitto start || /bin/true

exit 0
