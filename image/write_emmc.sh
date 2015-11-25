#!/bin/bash
#!/bin/bash
if [ "x$1" = "x" ]; then
    echo "please provide the image location"
    exit 1;
fi


while [ 1 ]; do
	../../mxsldr/mxsldr ../contrib/u-boot/wb5_usbfw.sb
	if [ $? = 0 ]; then
		sleep 10
		DISK=`dmesg | tail | grep "Attached SCS" | grep -Po "(?<=\[)([^\d]+)(?=\])"`
		echo "Disk: $DISK"
		[[ $DISK = "" ]] && echo "Empty disk" && exit 1;
		[[ $DISK = "sda" ]] && exit 1;
		[[ $DISK = "sdb" ]] && exit 1;
		# [[ $DISK = "sdc" ]] && exit 1;

		./write_card2.sh  $1 /dev/$DISK

		echo "echo b > /proc/sysrq-trigger" > /dev/ttyUSB0
		
		echo "done"
		break;
	fi
done