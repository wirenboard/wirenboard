#!/bin/bash

MUX_A=36
MUX_B=37
MUX_C=38

function init_mux() {
	if [ ! -e /sys/class/gpio/gpio${MUX_A} ]; then
		echo $MUX_A > /sys/class/gpio/export
	fi

	if [ ! -e /sys/class/gpio/gpio${MUX_B} ]; then
		echo $MUX_B > /sys/class/gpio/export
	fi

	if [ ! -e /sys/class/gpio/gpio${MUX_C} ]; then
		echo $MUX_C > /sys/class/gpio/export
	fi


	echo out > /sys/class/gpio/gpio${MUX_A}/direction
	echo out > /sys/class/gpio/gpio${MUX_B}/direction
	echo out > /sys/class/gpio/gpio${MUX_C}/direction

}
function set_mux() {
	echo "set mux c,b,a = $1,$2,$3"
	echo $1 > /sys/class/gpio/gpio${MUX_C}/value
	echo $2 > /sys/class/gpio/gpio${MUX_B}/value
	echo $3 > /sys/class/gpio/gpio${MUX_A}/value
}


init_mux

case "$1" in
	"0" |  "tb3" )
		set_mux 0 0 0
	;;
	"1" | "tb4" )
		set_mux 0 0 1
	;;
	"2" | "tb5" )
		set_mux 0 1 0
	;;
	"3" | "tb2" )
		set_mux 0 1 1
	;;
	"4" | "tb6" )
		set_mux 1 0 0
	;;
	"5" | "vin")
		set_mux 1 0 1
	;;
	"6" | "tb7" )
		set_mux 1 1 0
	;;
	"7" | "tb9" )
		set_mux 1 1 1
	;;

	* )
	echo "USAGE: $0 <0-7>|<tbX>|vin";

	;;
esac

