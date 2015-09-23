#!/bin/bash
. /etc/wb_env.sh

PORT=/dev/ttyAPP0

function debug() {
    echo $1 1>&2
}

function simcom_get_time() {
    #~ set_speed
    wb-gsm restart_if_broken

    REPORT_FILE=`mktemp`
    /usr/sbin/chat -s -r $REPORT_FILE  TIMEOUT 2 ABORT "ERROR" REPORT "+CCLK:" "" "AT+CCLK?" OK ""  > $PORT < $PORT
    RC=$?


    if [[ $RC != 0 ]] ; then
        debug "ERROR while getting time"
        rm $REPORT_FILE
        exit $RC;
    fi

    REPORT=`cat $REPORT_FILE | cut -d' ' -f6-`
    rm $REPORT_FILE

    TIME="${REPORT:8:20}"
    echo $TIME

}


function simcom_set_time() {
    wb-gsm restart_if_broken

    REPORT_FILE=`mktemp`
    /usr/sbin/chat -s  TIMEOUT 2 ABORT "ERROR" REPORT "OK" "" "AT+CCLK=\"$1\"" OK ""  > $PORT < $PORT
    RC=$?

    if [[ $RC != 0 ]] ; then
        debug "ERROR while setting time"
        exit $RC;
    fi

}

function sys_get_time() {
    date +%y/%m/%d,%H:%M:%S+00
}

function sys_set_time() {
    DATE=$1
    date -s "20${DATE/,/ }"
}


case "$1" in
	"save_time" )
		simcom_set_time `sys_get_time`
	;;

	"restore_time" )
        sys_set_time `simcom_get_time`
	;;

	"read" )
		simcom_get_time
	;;

	* )
		echo "USAGE: $0 [save_time|restore_time|read]";
	;;
esac

