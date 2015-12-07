#!/bin/bash
set -u -e
cd /root
export CONFIG_DIR=/root/configs
time /root/rootfs/create_rootfs.sh /rootfs 5
rm -f rootfs_base.tar.gz
/root/prep.sh
# TBD: run chroot:
# proot -R /rootfs -q qemu-arm-static -b /home/ivan4th /bin/bash
# TBD: -e USER=$USER, create user & group
# TBD: LC_ALL=ru_RU.UTF-8 (and maybe more env)
# Try to -v $HOME to both $HOME and /rootfs/$HOME
