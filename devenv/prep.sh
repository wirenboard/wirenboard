#!/bin/bash
set -u -e -x

ROOTFS=${ROOTFS:-"/rootfs"}
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR"/rootfs/rootfs_env.sh

prepare_chroot
services_disable

/bin/echo -e 'APT::Get::Assume-Yes "true";\nAPT::Get::force-yes "true";' >$ROOTFS/etc/apt/apt.conf.d/90forceyes
# we don't need the "Translations" files, so we're just wasting time and space by downloading them
/bin/echo -e 'Acquire::Languages "none";' > $ROOTFS/etc/apt/apt.conf.d/91no-languages

chr apt-get update

pkgs=(devscripts equivs build-essential \
    pkg-config bash-completion \
    cmake cdbs autoconf automake libtool \
    git git-man ccache
)

chr_apt_install "${pkgs[@]}"

cp /etc/profile.d/wbdev_profile.sh $ROOTFS/etc/profile.d/

chr apt-get clean
rm -rf $ROOTFS/dh-virtualenv
chr find /var/lib/apt/lists/ -type f -not -path "*/partial" -delete
chr ls -lh /var/lib/apt/lists/ || /bin/true
ls -lh $ROOTFS/var/lib/apt/lists/ || /bin/true
