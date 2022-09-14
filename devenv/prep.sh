#!/bin/bash
set -u -e -x

ROOTFS=${ROOTFS:-"/rootfs"}
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR"/rootfs/rootfs_env.sh

prepare_chroot
services_disable

/bin/echo -e 'APT::Get::Assume-Yes "true";\nAPT::Get::force-yes "true";' >$ROOTFS/etc/apt/apt.conf.d/90forceyes
chr apt-get update

pkgs=(devscripts equivs build-essential \
    pkg-config bash-completion \
    libgtest-dev google-mock cmake \
    cdbs autoconf automake libtool \
    knxd-dev knxd-tools knxd \
    git git-man gcc g++ linux-headers-${PLATFORM}
)


chr_apt_install "${pkgs[@]}"

##fix me
echo "/lib/arm-linux-gnueabi" >> /etc/ld.so.conf.d/multiarch.conf
echo "/usr/lib/arm-linux-gnueabi" >> /etc/ld.so.conf.d/multiarch.conf
echo "/usr/arm-linux-gnueabi/lib" >>  /etc/ld.so.conf.d/multiarch.conf
# for wb-mqtt-knx
if [ ! -e /usr/lib/x86_64-linux-gnu/libeibclient.so ]; then
#FIX ME
	ln -s /usr/lib/x86_64-linux-gnu/libeibclient.so.0 /usr/lib/x86_64-linux-gnu/libeibclient.so | true 
fi

# build and install google test and google mock
chr bash -c "cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/"

cp /usr/src/gmock/CMakeLists.txt $ROOTFS/usr/src/gmock
chr bash -c "ln -s /usr/src/gtest /usr/src/gmock/gtest"
chr bash -c "cd /usr/src/gmock && cmake . && make && mv libg* /usr/lib/"


cp /etc/profile.d/wbdev_profile.sh $ROOTFS/etc/profile.d/

chr apt-get clean
rm -rf $ROOTFS/dh-virtualenv
chr rm -rf /var/lib/apt/lists/
chr ls -lh /var/lib/apt/lists/ || /bin/true
ls -lh $ROOTFS/var/lib/apt/lists/ || /bin/true
