#!/bin/bash
. /etc/wb_env.sh
. /usr/lib/wb-gsm-common.sh

PORT=/dev/ttyAPP0

function debug() {
    echo $1 1>&2
}

function sys_get_time() {
    date -u +%y/%m/%d,%H:%M:%S
}

function sys_set_time() {
    DATE=$1
    date -u -s "20${DATE/,/ }"
}


case "$1" in
	"save_time" )
        gsm_init
		gsm_set_time `sys_get_time`
	;;

	"restore_time" )
        gsm_init
        sys_set_time `gsm_get_time`
	;;

	"read" )
        gsm_init
		gsm_get_time
	;;

	* )
		echo "USAGE: $0 [save_time|restore_time|read]";
	;;
esac

