#!/bin/bash
PWRKEY=6
RESET=7
PWRKEY_GPIO=/sys/class/gpio/gpio${PWRKEY}
RESET_GPIO=/sys/class/gpio/gpio${RESET}


function init() {
	if [ ! -e  $PWRKEY_GPIO ]; then
		echo $PWRKEY > /sys/class/gpio/export
	fi

	if [ ! -e  $RESET_GPIO ]; then
		echo $RESET > /sys/class/gpio/export
	fi
}


function toggle() {
	echo "toggle SIM900 state using PWRKEY"
	echo 0 > ${PWRKEY_GPIO}/value
	sleep 1
	echo 1 > ${PWRKEY_GPIO}/value
	sleep 1
	echo 0 > ${PWRKEY_GPIO}/value
}


init

echo out > ${PWRKEY_GPIO}/direction
echo out   > ${RESET_GPIO}/direction

echo 0 > ${RESET_GPIO}/value


case "$1" in
	"reset" )
		echo "reset SIM900"
		echo 1 > ${RESET_GPIO}/value
		sleep 0.5
		echo 0 > ${RESET_GPIO}/value
	;;

	"toggle" )
		toggle
	;;
	* )
		echo "USAGE: $0 toggle|<reset>";
		toggle
	;;
esac










