#!/bin/bash
set -u -e
cd /root

export ROOTFS_DIR="/rootfs/wheezy-armhf"
export RELEASE=wheezy
export ARCH=armhf
time /root/rootfs/create_rootfs.sh $ROOTFS_DIR 5
rm -f rootfs_base.tar.gz
/root/prep.sh

export ROOTFS_DIR="/rootfs/wheezy-armel"
export RELEASE=wheezy
export ARCH=armel
time /root/rootfs/create_rootfs.sh $ROOTFS_DIR 5
rm -f rootfs_base.tar.gz
/root/prep.sh
# TBD: run chroot:
# proot -R /rootfs -q qemu-arm-static -b /home/ivan4th /bin/bash
# TBD: -e USER=$USER, create user & group
# TBD: LC_ALL=ru_RU.UTF-8 (and maybe more env)
# Try to -v $HOME to both $HOME and /rootfs/$HOME
