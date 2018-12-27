#!/bin/bash
set -e
#set -x

ROOTFS_DIR=$ROOTFS
#REPO="http://ftp.debian.org/debian"
REPO="http://mirror.yandex.ru/debian/"
RELEASE=${RELEASE:-stretch}


if [[ ( "$#" < 1)  ]]
then
  echo "USAGE: $0 <BOARD> [list of additional repos]"
  echo "Override default rootfs path with ROOTFS env var"
  echo ""
  echo "How to attach additional repos:"
  echo -e "\t$0 <BOARD> \"http://localhost:8086/\""
  echo -e "Additional repo must have a public key file on http://<hostname>/repo.gpg.key"
  echo -e "In process, repo names will be expanded as \"deb <repo_address> ${RELEASE} main\""
  exit 1
fi

# flag showing usage of additional repo
USE_EXPERIMENTAL=false
if [[ $# -gt 1 ]]; then
    USE_EXPERIMENTAL=true
    ADD_REPOS="${@:2}"
fi

BOARD=$1
if [[ $BOARD = 6* ]]; then
    ARCH="armhf"
else
    ARCH="armel"
fi
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "${SCRIPT_DIR}"/rootfs_env.sh

. "$SCRIPT_DIR/../boards/init_board.sh"

OUTPUT=${ROOTFS}  # FIXME: use ROOTFS var consistently in all scripts 


[[ -e "$OUTPUT" ]] && die "output rootfs folder $OUTPUT already exists, exiting"

[[ -n "$__unshared" ]] || {
	[[ $EUID == 0 ]] || {
		exec sudo -E "$0" "$@"
	}

	# Jump into separate namespace
	export __unshared=1
	exec unshare -umi "$0" "$@"
}


mkdir -p $OUTPUT

export LC_ALL=C


# use alternative rootfs tarball for experimental builds (with additional repos)
if $USE_EXPERIMENTAL; then
    ROOTFS_BASE_TARBALL="${WORK_DIR}/rootfs_base_${RELEASE}_${ARCH}_dev.tar.gz"
else
    ROOTFS_BASE_TARBALL="${WORK_DIR}/rootfs_base_${RELEASE}_${ARCH}.tar.gz"
fi

ROOTFS_DIR=$OUTPUT

ADD_REPO_FILE=$OUTPUT/etc/apt/sources.list.d/additional.list
ADD_REPO_RELEASE=${ADD_REPO_RELEASE:-$RELEASE}
setup_additional_repos() {
    # setup additional repos

    mkdir -p `dirname $ADD_REPO_FILE`
    touch $ADD_REPO_FILE
    for repo in "${@}"; do
        echo "=> Setup additional repository $repo..."
        echo "deb $repo $ADD_REPO_RELEASE main" >> $ADD_REPO_FILE
        (wget $repo/repo.gpg.key -O- | chr apt-key add - ) ||
            echo "Warning: can't import repo.gpg.key for repo $repo"
    done
}

setup_additional_pins() {
    mkdir -p ${OUTPUT}/etc/apt/preferences.d/
    for repo in "${@}"; do
        local reponame="`echo $repo | sed 's#http://\([^:]*\)\(\:[0-9]\+\)\?/#\1#'`" # remove http:// and port number, leave only hostname
        local repofilename="`echo $reponame | sed 's/\./_/g'`"
        echo "Package: *" > ${OUTPUT}/etc/apt/preferences.d/dev-$repofilename
        echo "Pin: origin $reponame" >> ${OUTPUT}/etc/apt/preferences.d/dev-$repofilename
        echo "Pin-Priority: 991" >> ${OUTPUT}/etc/apt/preferences.d/dev-$repofilename
    done
}

maybe_setup_additional_pins() {
    if $USE_EXPERIMENTAL; then
        echo "Set APT pins for additional repos"
        setup_additional_pins "$ADD_REPOS"
    fi
}

install_contactless_repo() {
    rm -f ${OUTPUT}/etc/apt/sources.list.d/contactless*

	echo "Install initial repos"
	if [[ ${RELEASE} == "wheezy" ]]; then
        	echo "deb http://http.debian.net/debian ${RELEASE}-backports main" > ${OUTPUT}/etc/apt/sources.list.d/${RELEASE}-backports.list
	        echo "deb http://releases.contactless.ru/ ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/contactless.list
	elif [[ ${RELEASE} == "stretch" ]]; then
		echo "deb http://releases.contactless.ru/stable/${RELEASE} ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/contactless.list
	fi

	if [[ ${RELEASE} == "stretch" ]]; then
		echo "Install gnupg"
		chr apt-get update
		chr apt-get install -y gnupg1
	fi
	
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
    if $USE_EXPERIMENTAL; then
        echo "Install additional repos"
        setup_additional_repos "$ADD_REPOS"
    fi

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

    install_contactless_repo
    # apt pin
        echo "Set APT PIN" 
        echo "Package: *" > ${OUTPUT}/etc/apt/preferences
        echo "Pin: origin releases.contactless.ru" >> ${OUTPUT}/etc/apt/preferences
        echo "Pin-Priority: 990" >> ${OUTPUT}/etc/apt/preferences

    maybe_setup_additional_pins
        
	echo "Install public key for contactless repo"
	chr apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
	board_override_repos
    
    # setup additional repositories
    echo "Install additional repos"
    setup_additional_repos "${@:2}"

	echo "Update&upgrade apt"
	chr_apt_update
    chr_apt_install contactless-keyring

	chr apt-get -y --force-yes upgrade

	echo "Setup locales"
    chr_apt_install locales
	echo "en_GB.UTF-8 UTF-8" > ${OUTPUT}/etc/locale.gen
	echo "en_US.UTF-8 UTF-8" >> ${OUTPUT}/etc/locale.gen
	echo "ru_RU.UTF-8 UTF-8" >> ${OUTPUT}/etc/locale.gen
	chr /usr/sbin/locale-gen
	chr update-locale

    echo "Install additional packages"
    chr_apt_install netbase ifupdown \
        iproute openssh-server \
        iputils-ping wget udev net-tools ntpdate ntp vim nano less \
        tzdata mc wireless-tools usbutils \
        i2c-tools isc-dhcp-client wpasupplicant psmisc curl dnsmasq gammu \
        python-serial memtester apt-utils dialog locales \
        python3-minimal unzip minicom iw ppp libmodbus5 \
        python-smbus ssmtp moreutils liblog4cpp5-dev firmware-realtek

	if [[ ${RELEASE} == "wheezy" ]]; then
        # not present at stretch
        chr_apt_install --force-yes console-tools module-init-tools
        chr_apt_install --force-yes liblog4cpp5
	elif [[ ${RELEASE} == "stretch" ]]; then
        chr_apt_install --force-yes liblog4cpp5v5 logrotate
        fi

	echo "Creating $ROOTFS_BASE_TARBALL"
	pushd ${OUTPUT}
	tar czpf $ROOTFS_BASE_TARBALL --one-file-system ./
	popd
fi

echo "Cleanup rootfs"
chr_nofail dpkg -r geoip-database

echo "Creating /mnt/data mountpoint"
mkdir ${OUTPUT}/mnt/data

echo "Restore pins for experimental repos if necessary"
maybe_setup_additional_pins
chr_apt_update

echo "Install some packages before wb-configs (to preserve conffiles diversions)"
chr_apt_install libnss-mdns kmod

echo "Install wb-configs"
chr_apt_install wb-configs

# restore apt pin for experimental repos
maybe_setup_additional_pins

echo "Install packages from contactless repo"
pkgs=(
    cmux hubpower python-wb-io modbus-utils serial-tool busybox busybox-syslogd
    libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients python-mosquitto
    openssl ca-certificates avahi-daemon pps-tools linux-image-${KERNEL_FLAVOUR} device-tree-compiler
)

chr_apt_update
    
if [[ ${RELEASE} == "stretch" ]]; then
    chr_apt_install libssl1.0-dev systemd-sysv
fi

chr_apt_install "${pkgs[@]}"
chr_apt_update
# stop mosquitto on host
service mosquitto stop || /bin/true

chr /usr/sbin/mosquitto -d -c /etc/mosquitto/mosquitto.conf
chr_apt_install wb-mqtt-confed

date '+%Y%m%d%H%M' > ${OUTPUT}/etc/wb-fw-version

set_fdt() {
    echo "" > 
    cat > ${OUTPUT}/boot/uEnv.txt << EOF
# The fdt_file parameter is for compatibility with older bootloader
# versions normally found on Wiren Boards older than WB6.5.

# In order to override devicetree on boards with newer bootloaders set both 
# fdt_file and fdt_file_override here.

fdt_file=/boot/dtbs/${1}.dtb
#fdt_file_override=/path/to/.dtb
EOF
}

install_wb5_packages() {
    pkgs=(
		wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-mqtt-db \
		wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils \
		wb-mqtt-dac wb-mqtt-homeui wb-hwconf-manager wb-test-suite u-boot-tools \
		wb-dt-overlays wb-mqtt-mbgate wb-mqtt-db-cli cron bluez-hcidump wb-daemon-watchdogs
    )

    if [[ ${RELEASE} == "wheezy" ]]; then
	chr_apt_install --force-yes lirc-scripts
    fi

    if [[ ${RELEASE} == "stretch" ]]; then
	chr_apt_install --force-yes libateccssl1.1
    fi
    export FORCE_WB_VERSION=$BOARD
    chr_apt_install "${pkgs[@]}"
}

[[ "${#BOARD_PACKAGES}" -gt 0 ]] && chr_apt_install "${BOARD_PACKAGES[@]}"

board_install

[[ -f ${OUTPUT}/var/run/mosquitto.pid ]] && chr /bin/bash -c 'kill "`cat /var/run/mosquitto.pid`"'

# remove additional repo files
rm -rf $ADD_REPO_FILE
rm -rf ${OUTPUT}/etc/apt/preferences.d/dev-*

chr apt-get clean
rm -rf ${OUTPUT}/run/* ${OUTPUT}/var/cache/apt/archives/* ${OUTPUT}/var/lib/apt/lists/*

rm -f ${OUTPUT}/etc/apt/sources.list.d/local.list

# removing SSH host keys
rm -f ${OUTPUT}/etc/ssh/ssh_host_* || /bin/true

# reverting ssmtp kludge
# NOTE: always use readlink -f or realpath for inline Perl stuff,
# because it will not preserve symlinks
sed "/$(hostname)/d" -i "`readlink -f ${OUTPUT}/etc/hosts`"

# (re-)start mosquitto on host
service mosquitto start || /bin/true

exit 0
