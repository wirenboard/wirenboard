#!/bin/bash
set -u -e

ROOTFS=${ROOTFS:-"/rootfs"}
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR"/rootfs/rootfs_env.sh

LIBLOG4CPP5DEV_DEB="http://ftp.ru.debian.org/debian/pool/main/l/log4cpp/liblog4cpp5-dev_1.0-4_${ARCH}.deb"
prepare_chroot
services_disable

/bin/echo -e 'APT::Get::Assume-Yes "true";\nAPT::Get::force-yes "true";' >$ROOTFS/etc/apt/apt.conf.d/90forceyes
chr apt-get update

if [[ ${RELEASE} == "wheezy" ]]; then
chr apt-get install -y devscripts python-virtualenv equivs build-essential \
    libmosquittopp-dev libmosquitto-dev pkg-config gcc-4.7 g++-4.7 libmodbus-dev \
    libwbmqtt-dev libcurl4-gnutls-dev libsqlite3-dev bash-completion \
    valgrind libgtest-dev google-mock cmake liblircclient-dev python-setuptools \
    cdbs libpng12-dev libqt4-dev autoconf automake libtool libpthsem-dev libpthsem20 \
    libusb-1.0-0-dev knxd-dev knxd-tools \
    cdbs libpng12-dev libqt4-dev linux-headers-4.1.15-imxv5-x0.1
elif [[ ${RELEASE} == "stretch" ]]; then
chr_install_deb_url ${LIBLOG4CPP5DEV_DEB}
chr apt-get install -y devscripts python-virtualenv equivs build-essential \
    libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev \
    libcurl4-gnutls-dev libsqlite3-dev bash-completion \
    libgtest-dev google-mock
chr apt-get install -y cmake liblircclient-dev python-setuptools \
    cdbs libpng-dev libqt4-dev autoconf automake libtool libusb-1.0-0-dev 
fi
# install git from backports to support desktop latest Git configs
chr apt-get install -y -t stretch-backports git git-man

(rm -rf $ROOTFS/dh-virtualenv && cd $ROOTFS && git clone https://github.com/spotify/dh-virtualenv.git && cd dh-virtualenv && git checkout 0.10)
chr bash -c "cd /dh-virtualenv && mk-build-deps -ri && dpkg-buildpackage -us -uc -b"
chr bash -c "dpkg -i /dh-virtualenv_*.deb"

# build and install google test and google mock
chr bash -c "cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/"

cp /usr/src/gmock/CMakeLists.txt $ROOTFS/usr/src/gmock
chr bash -c "ln -s /usr/src/gtest /usr/src/gmock/gtest"
chr bash -c "cd /usr/src/gmock && cmake . && make && mv libg* /usr/lib/"


cp /etc/profile.d/wbdev_profile.sh $ROOTFS/etc/profile.d/

chr apt-get clean
rm -rf $ROOTFS/dh-virtualenv
