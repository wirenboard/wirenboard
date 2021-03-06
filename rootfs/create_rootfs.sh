#!/bin/bash
set -e
#set -x

ROOTFS_DIR=$ROOTFS
DEBIAN_RELEASE=${DEBIAN_RELEASE:-stretch}

WB_REPO=${WB_REPO:-'http://deb.wirenboard.com/'}
WB_REPO_PREFIX=${WB_REPO_PREFIX:-''}
WB_TEMP_REPO=${WB_TEMP_REPO:-false}
WB_RELEASE=${WB_RELEASE:-stable}

DEFAULT_ADD_REPO_RELEASE=${ADD_REPO_RELEASE:-$DEBIAN_RELEASE}
DEFAULT_ADD_REPO_COMPONENT=${ADD_REPO_COMPONENT:-"main"}

if [[ ( "$#" < 1)  ]]
then
  echo "USAGE: $0 <BOARD> [list of additional repos]"
  echo ""
  echo "Environment variables:"
  echo -e "\tROOTFS\tOverrides default rootfs path"
  echo -e "\tWB_REPO\tOverrides default repository URL (default '$WB_REPO')"
  echo -e "\tWB_REPO_PREFIX\tOverrides default repository prefix after URL (default '$WB_REPO_PREFIX')"
  echo -e "\tWB_RELEASE\tOverrides default release (default '$WB_RELEASE')"
  echo -e "\tWB_TEMP_REPO\tSet to 'true' if default repository will be unavailable after build"
  echo -e "\tDEBIAN_RELEASE\tSets Debian release (default '$DEBIAN_RELEASE')"
  echo ""
  echo "How to use additional repos:"
  echo -e "\t $0 <BOARD> \"http://localhost:8086/\" [more repos...]"
  echo -e "By default, repos  will be expanded as"
  echo -e "\t \"deb <repo_address> ${DEFAULT_ADD_REPO_RELEASE} ${DEFAULT_ADD_REPO_COMPONENT}\"."
  echo -e "Repository will be added with [trusted=yes], so no key is required."
  echo -e "\nYou can specify release and component like this (optional):"
  echo -e "\t \"http://example.com/path/to@release:component\""
  exit 1
fi

# flag showing usage of additional repo
USE_EXPERIMENTAL=false
if [[ $# -gt 1 ]]; then
    USE_EXPERIMENTAL=true
    ADD_REPOS="${@:2}"
fi

BOARD=$1
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "${SCRIPT_DIR}"/rootfs_env.sh

. "$SCRIPT_DIR/../boards/init_board.sh"

OUTPUT=${ROOTFS}  # FIXME: use ROOTFS var consistently in all scripts 
WB_TARGET=${WB_TARGET:-"${REPO_PLATFORM}/${DEBIAN_RELEASE}"}

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

# this function returns env variables:
#   repo_url repo_release repo_component
parse_repo_entry() {
    local repo=$1
    local repo_parts
    local repo_tail_parts

    IFS='@' read -ra repo_parts <<< "$repo"
    repo_url="${repo_parts[0]}"
    local repo_tail="${repo_parts[1]}"

    if [[ -n "$repo_tail" ]]; then
        IFS=':' read -ra repo_tail_parts <<< "$repo_tail"
        repo_release="${repo_tail_parts[0]}"
        repo_component="${repo_tail_parts[1]}"
    fi

    [[ -z "$repo_url" ]] && {
        echo "Error while parsing repo entry '$repo'" >&2
        exit 2
    }

    [[ -z "$repo_release" ]] && repo_release=$DEFAULT_ADD_REPO_RELEASE || true
    [[ -z "$repo_component" ]] && repo_component=$DEFAULT_ADD_REPO_COMPONENT || true
}

check_additional_repos() {
    for repo in "${@}"; do
        parse_repo_entry $repo
        echo "Checking presence of repo $repo"

		wget "${repo_url}/dists/${repo_release}/Release" -O- >/dev/null || {
            echo "> Can't access repo $repo, check everything again"
            exit 3
        }
    done
}

[[ -n "$ADD_REPOS" ]] && {
    echo "Checking if all additional repos are available"
    check_additional_repos $ADD_REPOS
}

FULL_REPO_URL=`echo "$WB_REPO/$WB_REPO_PREFIX/$WB_TARGET" | sed 's#//\+#/#g' | sed 's#http\(s\)\?:/#http\1://#g'`
WB_TARGET_FOR_FILENAME=`echo $WB_TARGET | sed 's#/#_#'`

WB_REPO_HASH=`echo "$FULL_REPO_URL $ADD_REPOS" | sha256sum - | head -c 8`
ROOTFS_BASE_SUFFIX="${WB_RELEASE}_${WB_TARGET_FOR_FILENAME}_r${WB_REPO_HASH}"
ROOTFS_BASE_TARBALL="${WORK_DIR}/rootfs_base_${ROOTFS_BASE_SUFFIX}.tar.gz"

ROOTFS_DIR=$OUTPUT

ADD_REPO_FILE=$OUTPUT/etc/apt/sources.list.d/wb-additional-tmp.list
ADD_REPO_PIN_FILE=$OUTPUT/etc/apt/preferences.d/00-wb-additional-tmp

APT_LIST_TMP_FNAME=${OUTPUT}/etc/apt/sources.list.d/wb-install-tmp.list
APT_PIN_TMP_FNAME=${OUTPUT}/etc/apt/preferences.d/01wb-install-tmp

REPO="http://mirror.yandex.ru/debian/"

setup_additional_repos() {
    # setup additional repos

    mkdir -p `dirname $ADD_REPO_FILE`
    echo > $ADD_REPO_FILE
	echo > $ADD_REPO_PIN_FILE
    for repo in "${@}"; do
        parse_repo_entry $repo

        echo "=> Setup additional repository $repo..."
        echo "deb [trusted=yes] $repo_url $repo_release $repo_component" >> $ADD_REPO_FILE

		echo "Setup pinning"

		local o=`wget "${repo_url}/dists/${repo_release}/Release" -O- | head | grep -P -o "Origin: \K[\w\_\-]+"`
		local l=`wget "${repo_url}/dists/${repo_release}/Release" -O- | head | grep -P -o "Label: \K[\w\_\-]+"`

		echo "Package: *" >> ${ADD_REPO_PIN_FILE}
		echo "Pin: release o=$o, l=$l" >> ${ADD_REPO_PIN_FILE}
		echo "Pin-Priority: 1001" >> ${ADD_REPO_PIN_FILE}  # allow downgrade to these versions
		echo >> ${ADD_REPO_PIN_FILE} # mandatory newline
    done

	echo "Addtitional repo $ADD_REPO_FILE contents:"
	cat  $ADD_REPO_FILE
	echo "Addtitional pin $ADD_REPO_PIN_FILE contents:"
	cat  $ADD_REPO_PIN_FILE
	
}

install_contactless_repo() {
    rm -f ${APT_LIST_TMP_FNAME}

	echo "Install initial repos"
    echo "deb $FULL_REPO_URL $WB_RELEASE main" >  ${APT_LIST_TMP_FNAME}

    if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
		echo "Install gnupg"
		chr apt-get update
		chr apt-get install -y gnupg1
	fi
	
}

echo "Wirenboard repo: $FULL_REPO_URL, release $WB_RELEASE"

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
        setup_additional_repos $ADD_REPOS
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
		${DEBIAN_RELEASE} ${OUTPUT} ${REPO}

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
        echo "deb ${REPO} ${DEBIAN_RELEASE} main" >${OUTPUT}/etc/apt/sources.list

		if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
			echo "deb ${REPO} ${DEBIAN_RELEASE}-updates main" >>${OUTPUT}/etc/apt/sources.list
			echo "deb http://security.debian.org ${DEBIAN_RELEASE}/updates main" >>${OUTPUT}/etc/apt/sources.list
		fi


    install_contactless_repo
    # apt pin
    echo "Set temporary APT PIN" 
    echo "Package: *" > ${APT_PIN_TMP_FNAME}
    echo "Pin: release o=wirenboard, a=$WB_RELEASE" >> ${APT_PIN_TMP_FNAME}
    echo "Pin-Priority: 990" >> ${APT_PIN_TMP_FNAME}

       
	echo "Install public key for contactless repo"
	chr apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
	board_override_repos
    
    # setup additional repositories
    echo "Install additional repos"
    setup_additional_repos ${@:2}

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

	if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
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

chr_apt_update

echo "Install some packages before wb-essential (to preserve conffiles diversions in wb-configs)"
chr_apt_install libnss-mdns kmod

echo "Install wb-essential (with wb-configs)"
chr_apt_install linux-image-${KERNEL_FLAVOUR} wb-essential

echo "Install packages from contactless repo"
pkgs=(
    cmux hubpower python-wb-io modbus-utils serial-tool busybox
    libmosquittopp1 libmosquitto1 mosquitto mosquitto-clients python-mosquitto
    openssl ca-certificates avahi-daemon pps-tools device-tree-compiler
)

chr_apt_update
    
if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
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
        wb-suite netplug hostapd bluez can-utils u-boot-tools \
		cron bluez-hcidump wb-test-suite
    )

    if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
	chr_apt_install --force-yes libateccssl1.1 knxd knxd-tools
    fi
    chr_apt_install "${pkgs[@]}"
}

[[ "${#BOARD_PACKAGES}" -gt 0 ]] && chr_apt_install "${BOARD_PACKAGES[@]}"

board_install

if chr [ -f /var/run/mosquitto.pid ]; then
	# trigger saving persistence db to disk
	echo "saving persistence"
	chr cat /var/run/mosquitto.pid || true
	ps aux | grep mosquitto
	chr /bin/bash -c 'kill "`cat /var/run/mosquitto.pid`"'
fi

echo 'remove additional repo files'
rm -rf $ADD_REPO_FILE
rm -rf $ADD_REPO_PIN_FILE

rm -f ${OUTPUT}/etc/apt/sources.list.d/local.list
if [[ ${DEBIAN_RELEASE} == "stretch" ]]; then
	rm -f ${OUTPUT}/etc/apt/sources.list
fi

# removing SSH host keys
rm -f ${OUTPUT}/etc/ssh/ssh_host_* || /bin/true

# reverting ssmtp kludge
# NOTE: always use readlink -f or realpath for inline Perl stuff,
# because it will not preserve symlinks
sed "/$(hostname)/d" -i "`readlink -f ${OUTPUT}/etc/hosts`"

echo "remove installation time apt pinning and lists"
rm ${APT_LIST_TMP_FNAME}
rm ${APT_PIN_TMP_FNAME}

if ! $WB_TEMP_REPO; then
    echo "regenerate default apt lists for consistency"
    chr wb-release -r
fi

echo "cleanup apt caches"
chr apt-get clean
rm -rf ${OUTPUT}/run/* ${OUTPUT}/var/cache/apt/archives/* ${OUTPUT}/var/lib/apt/lists/*

# (re-)start mosquitto on host
service mosquitto start || /bin/true

exit 0
