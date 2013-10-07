#!/bin/bash
PWRKEY=6
RESET=7

echo $PWRKEY > /sys/class/gpio/export
echo $RESET > /sys/class/gpio/export

PWRKEY_GPIO=/sys/class/gpio/gpio${PWRKEY}
RESET_GPIO=/sys/class/gpio/gpio${RESET}


function toggle() {
	echo 0 > ${PWRKEY_GPIO}/value
	sleep 1
	echo 1 > ${PWRKEY_GPIO}/value
	sleep 1
	echo 0 > ${PWRKEY_GPIO}/value
}

echo out > ${PWRKEY_GPIO}/direction
echo out   > ${RESET_GPIO}direction

echo 0 > ${RESET_GPIO}/value


case "$1" in
	"reset" )
		echo "reset SIM900"
		echo 1 > ${RESET_GPIO}/value
		sleep 0.5
		echo 0 > ${RESET_GPIO}/value
	;;

	"toggle" )
		echo "toggle SIM900 state using PWRKEY"
		toggle
	;;
	* )
		echo "USAGE: $0 [toggle|reset]\n toggle by default";
		toggle
	;;
esac










