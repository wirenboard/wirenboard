#!/bin/bash
set -u -e
cd /root

do_build() {
	export RELEASE=$1 ARCH=$2 BOARD=$3
	export ROOTFS="/rootfs/$RELEASE-$ARCH"
	time /root/rootfs/create_rootfs.sh $BOARD
	rm -f /root/output/rootfs_base_${ARCH}.tar.gz
	/root/prep.sh
}

do_build_sbuild_env() {
	export RELEASE=$12
	export ROOTFS="/srv/chroot/sbuild-$1-cross"
	export CHROOT_NAME="$1-amd64-sbuild"

	sbuild-createchroot --include="crossbuild-essential-armhf crossbuild-essential-armel build-essential libarchive-zip-perl libtimedate-perl libglib2.0-0 libcroco3 pkg-config libfile-stripnondeterminism-perl gettext intltool-debian po-debconf dh-autoreconf dh-strip-nondeterminism debhelper libgtest-dev cmake"  $1 ${ROOTFS} http://deb.debian.org/debian

	echo "deb [arch=amd64,armhf,armel] http://releases.contactless.ru/stable/stretch stretch main" > ${ROOTFS}/etc/apt/sources.list.d/contactless.list
	cp /usr/share/keyrings/contactless-keyring.gpg ${ROOTFS}/etc/apt/trusted.gpg.d/

	schroot -c ${CHROOT_NAME} --directory=/ -- dpkg --add-architecture armhf
	schroot -c ${CHROOT_NAME} --directory=/ -- dpkg --add-architecture armel
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get update

	#install multi-arch common build dependencies
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y install libssl-dev:armhf linux-libc-dev:armhf libc6-dev:armhf libc-ares2:armhf libssl-dev:armel linux-libc-dev:armel libc6-dev:armel libc-ares2:armel

	#make gtest
	schroot -c ${CHROOT_NAME} --directory=/ -- bash -c "cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/"

	# remove essential but conflicting libraries
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y --allow-remove-essential remove libmosquittopp-dev libmosquitto-dev  libmosquitto1 libmosquittopp1 libcomerr2 e2fslibs

	#clean
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y autoremove
}

do_build stretch armel 58
do_build stretch armhf 6x
do_build wheezy armel 58

do_build_sbuild_env stretch 
do_build_sbuild_env buster 

# TBD: run chroot:
# proot -R /rootfs -q qemu-arm-static -b /home/ivan4th /bin/bash
# TBD: -e USER=$USER, create user & group
# TBD: LC_ALL=ru_RU.UTF-8 (and maybe more env)
# Try to -v $HOME to both $HOME and /rootfs/$HOME
