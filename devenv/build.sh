#!/bin/bash
set -u -e
cd /root

source /root/common-deps.sh

do_build() {
	export RELEASE=$1 ARCH=$2 BOARD=$3 PLATFORM=$4 WB_RELEASE=${5:-stable} ADDITIONAL_REPOS=${6:-}
	export ROOTFS="/rootfs/$RELEASE-$ARCH"

	time DEBIAN_RELEASE=$RELEASE ARCH=$ARCH WB_RELEASE=$WB_RELEASE /root/rootfs/create_rootfs.sh $BOARD $ADDITIONAL_REPOS

	rm -f /root/output/rootfs_base_${ARCH}.tar.gz
	/root/prep.sh
}

do_build_sbuild_env() {
	export RELEASE=$1
	export ROOTFS="/srv/chroot/sbuild-${RELEASE}-cross"
	export CHROOT_NAME="${RELEASE}-amd64-sbuild"

	shift
	local ADD_PACKAGES=("$@")

	REPO="http://debian-mirror.wirenboard.com/debian"
	if [[ "$RELEASE" = "stretch" ]]; then
		REPO="http://archive.debian.org/debian"
	fi

	sbuild-createchroot --include="crossbuild-essential-arm64 crossbuild-essential-armhf crossbuild-essential-armel build-essential libarchive-zip-perl libtimedate-perl libglib2.0-0 pkg-config libfile-stripnondeterminism-perl gettext intltool-debian po-debconf dh-autoreconf dh-strip-nondeterminism debhelper libgtest-dev cmake git ca-certificates ccache"  ${RELEASE} ${ROOTFS} ${REPO}
	SCHROOT_CONF="$(find /etc/schroot/chroot.d/ -name "${CHROOT_NAME}*" -type f | head -n1)"
	touch /etc/ccache.conf  # make schroot's copyfiles happy

	schroot -c ${CHROOT_NAME} --directory=/ -- dpkg --add-architecture arm64
	schroot -c ${CHROOT_NAME} --directory=/ -- dpkg --add-architecture armhf
	schroot -c ${CHROOT_NAME} --directory=/ -- dpkg --add-architecture armel
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get update

	#install mosquitto from debian repo to avoid future conflicts with contactless versions
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y install \
		libmosquittopp-dev:arm64 libmosquitto-dev:arm64 \
		libmosquittopp-dev:armhf libmosquitto-dev:armhf \
		libmosquittopp-dev:armel libmosquitto-dev:armel

	#add conactless repo
	echo "deb http://deb.wirenboard.com/dev-tools stable main" > ${ROOTFS}/etc/apt/sources.list.d/wirenboard-dev-tools.list
	cp /usr/share/keyrings/contactless-keyring.gpg ${ROOTFS}/etc/apt/trusted.gpg.d/

	cat <<EOF >${ROOTFS}/etc/apt/preferences.d/wb-releases
Package: *:any
Pin: release o=wirenboard a=pool
Pin-Priority: 10

Package: *:any
Pin: release o=wirenboard a=unstable
Pin-Priority: 990

Package: *:any
Pin: release o=wirenboard
Pin-Priority: 991
EOF

	if [[ "$RELEASE" = "stretch" ]]; then
		echo "deb http://archive.debian.org/debian stretch-backports main" > ${ROOTFS}/etc/apt/sources.list.d/stretch-backports.list
		cat <<EOF >${ROOTFS}/etc/apt/preferences.d/nodejs
Package: node*:any npm:any libuv1*:any
Pin: release a=stretch-backports
Pin-Priority: 510
EOF
	elif [[ "$RELEASE" = "bullseye" ]]; then
		echo "deb http://debian-mirror.wirenboard.com/debian bullseye-backports main" > ${ROOTFS}/etc/apt/sources.list.d/bullseye-backports.list
		cat <<EOF >${ROOTFS}/etc/apt/preferences.d/bullseye-backports
Package: libnm0 libmbim-*:any libqmi-*:any gir1.2-mbim-1.0 git1.2-qmi-1.0
Pin: release a=bullseye-backports
Pin-Priority: 510
EOF
	fi

	# prevent e2fsprogs packages from being installed from wb repo, it messes up with host versions.
	# it is only needed for actual hardware anyway
	cat <<EOF >${ROOTFS}/etc/apt/preferences.d/000libext2fs
Package: src:e2fsprogs:any
Pin: release o=wirenboard
Pin-Priority: -1
EOF

	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get update

	#install multi-arch common build dependencies
	schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y install \
		libssl-dev:arm64 linux-libc-dev:arm64 libc6-dev:arm64 libc-ares2:arm64 \
		libssl-dev:armhf linux-libc-dev:armhf libc6-dev:armhf libc-ares2:armhf \
		libssl-dev:armel linux-libc-dev:armel libc6-dev:armel libc-ares2:armel \
		golang-go node-rimraf python3-jinja2 \
		"${ADD_PACKAGES[@]}"

	#virtualization support packages
	cp /usr/bin/qemu-{aarch64,arm}-static ${ROOTFS}/usr/bin/

	#install precompiled gtest and gmock
	if [[ "$RELEASE" = "stretch" ]]; then
		schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y install -t stretch-backports libgtest-dev:armhf libgtest-dev:armel libgtest-dev libgmock-dev:armhf libgmock-dev:armel libgmock-dev
	else
		schroot -c ${CHROOT_NAME} --directory=/ -- apt-get -y install libgtest-dev:arm64 libgtest-dev:armhf libgtest-dev:armel libgtest-dev libgmock-dev:arm64 libgmock-dev:armhf libgmock-dev:armel libgmock-dev
	fi

	# sbuild from stretch overrides DEB_BUILD_OPTIONS, so fix that  
	if dpkg --compare-versions `dpkg -s sbuild | grep  -oP "Version: \K.*$"` lt 0.78.0; then
		cat <<EOF > ${ROOTFS}/deb_build_options_wrapper.sh
#!/bin/bash
DEB_BUILD_OPTIONS=\${_DEB_BUILD_OPTIONS} "\$@"
EOF
		cat <<EOF > /etc/sbuild/sbuild.conf
use Dpkg::Build::Info;
\$environment_filter = [Dpkg::Build::Info::get_build_env_whitelist(), '_DEB_BUILD_OPTIONS'];
\$build_env_cmnd = '/deb_build_options_wrapper.sh';
EOF
		chmod a+x ${ROOTFS}/deb_build_options_wrapper.sh
	fi

	#output everyting on screen instead of file
	echo "\$nolog = 1;" >> /etc/sbuild/sbuild.conf

	# enable ccache wrapper
	echo "command-prefix=/usr/local/bin/ccache-setup" >> "${SCHROOT_CONF}"

	# set correct symlink to /dev/ptmx
	rm -f ${ROOTFS}/dev/ptmx
	ln -s /dev/pts/ptmx ${ROOTFS}/dev/ptmx
}

do_build stretch armel 58 wb2
do_build stretch armhf 6x wb6

do_build bullseye armhf 6x wb6
do_build bullseye arm64 8x wb8 testing http://deb.wirenboard.com/all@experimental.wb8:main

do_build_sbuild_env stretch
do_build_sbuild_env bullseye "${KNOWN_BUILD_DEPS[@]}"

# TBD: run chroot:
# proot -R /rootfs -q qemu-arm-static -b /home/ivan4th /bin/bash
# TBD: -e USER=$USER, create user & group
# TBD: LC_ALL=ru_RU.UTF-8 (and maybe more env)
# Try to -v $HOME to both $HOME and /rootfs/$HOME
