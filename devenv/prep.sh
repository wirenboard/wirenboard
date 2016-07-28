#!/bin/bash
set -u -e

ROOTFS_DIR="/rootfs"
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR"/rootfs/rootfs_env.sh

prepare_chroot
services_disable

/bin/echo -e 'APT::Get::Assume-Yes "true";\nAPT::Get::force-yes "true";' >/rootfs/etc/apt/apt.conf.d/90forceyes
chr apt-get update
chr apt-get install -y devscripts python-virtualenv git equivs build-essential \
    libmosquittopp-dev libmosquitto-dev pkg-config gcc-4.7 g++-4.7 libmodbus-dev \
    libwbmqtt-dev libcurl4-gnutls-dev libsqlite3-dev bash-completion \
    valgrind libgtest-dev cmake liblircclient-dev liblog4cpp5-dev python-setuptools

(rm -rf /rootfs/dh-virtualenv && cd /rootfs && git clone https://github.com/spotify/dh-virtualenv.git && cd dh-virtualenv && git checkout 0.10)
chr bash -c "cd /dh-virtualenv && mk-build-deps -ri && dpkg-buildpackage -us -uc -b"
chr bash -c "dpkg -i /dh-virtualenv_*.deb"

# build and install google test
chr bash -c "cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/"

cp /etc/profile.d/wbdev_profile.sh /rootfs/etc/profile.d/

chr apt-get clean
rm -rf /rootfs/dh-virtualenv
