#!/bin/bash

if [ $# -ne 2 ]
then
  echo "USAGE: tools/copy_kernel.sh <kernel prefix> <path to rootfs>"
  exit 1
fi
kernel_version=$1
echo "kernl version is $kernel_version"

sudo tar xfv $kernel_version-firmware.tar.gz -C $2/lib/firmware/
sudo tar xfv $kernel_version-modules.tar.gz -C $2/
sudo tar xfv $kernel_version-dtbs.tar.gz -C $2/boot/dtbs/
sudo cp $kernel_version.zImage  $2/boot/zImage
