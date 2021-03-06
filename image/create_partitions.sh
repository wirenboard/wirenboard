#!/bin/bash

if [ -z "$1" ]; then
	echo "USAGE: $0 <sdcard device>"
	exit 1
fi

if [ "$1" == "/dev/sda" ]; then
	echo "Attempt to rewrite sda part table";
	exit 1
fi

sudo dd if=/dev/zero of=${1} bs=1M count=5 conv=notrunc
sudo sfdisk --in-order --Linux --unit M ${1} <<-__EOF__
4,16,0x53,-
,,,-
__EOF__
