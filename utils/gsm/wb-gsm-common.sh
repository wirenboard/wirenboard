#!/bin/bash
. /etc/wb_env.sh

PORT=/dev/ttyAPP0

PWRKEY_GPIO=/sys/class/gpio/gpio${WB_GPIO_GSM_PWRKEY}
RESET_GPIO=/sys/class/gpio/gpio${WB_GPIO_GSM_RESET}

#32
POWER_GPIO=/sys/class/gpio/gpio${WB_GPIO_GSM_POWER}
STATUS_GPIO=/sys/class/gpio/gpio${WB_GPIO_GSM_STATUS}

function debug() {
    echo $1 1>&2
}

function gpio_set_dir() {
    CUR_DIRECTION=`cat "/sys/class/gpio/gpio$1/direction"`
    if [ ! $CUR_DIRECTION = "$2" ]; then
        echo "$2" > /sys/class/gpio/gpio$1/direction
    fi

}


function gpio_set_value() {
    echo $2 > /sys/class/gpio/gpio$1/value

}

function gpio_get_value() {
    cat /sys/class/gpio/gpio$1/value
}

function gpio_export() {
    if [ ! -e  /sys/class/gpio/gpio$1  ]; then
        echo $1 > /sys/class/gpio/export
    fi
}


function get_model() {
    set_speed
    wb-gsm restart_if_broken

    REPORT_FILE=`mktemp`
    /usr/sbin/chat -s -r $REPORT_FILE  TIMEOUT 2 ABORT "ERROR" REPORT "\r\n" "" "AT+CGMM" OK ""  > $PORT < $PORT
    RC=$?


    if [[ $RC != 0 ]] ; then
        debug "ERROR while getting modem model"
        rm $REPORT_FILE
        exit $RC;
    fi

    REPORT=`cat $REPORT_FILE | sed -n 2p | sed 's/+CGMM: //'`
    rm $REPORT_FILE

    echo "$REPORT"
}

function is_neoway_m660a() {
    MODEL=`get_model`
    if [ "$MODEL" == "M660A" ]; then
        return 0;
    else
        return 1;
    fi
}

function gsm_init() {
    set_speed

    if [ "$WB_GSM_POWER_TYPE" = "0" ]; then
        debug "No GSM modem present, exiting"
        exit 1
    fi

    gpio_export $WB_GPIO_GSM_PWRKEY
    gpio_set_dir $WB_GPIO_GSM_PWRKEY out


    if [ ${WB_GSM_POWER_TYPE} = "1" ]; then
        gpio_export $WB_GPIO_GSM_RESET
        gpio_set_dir $WB_GPIO_GSM_RESET out
        gpio_set_value $WB_GPIO_GSM_RESET 0
    fi

    if [ ${WB_GSM_POWER_TYPE} = "2" ]; then
        gpio_export $WB_GPIO_GSM_POWER
        gpio_set_dir $WB_GPIO_GSM_POWER out
    fi

    if [ ${WB_GSM_HAS_STATUS_PIN} = "1" ]; then
        gpio_export $WB_GPIO_GSM_STATUS
        gpio_set_dir $WB_GPIO_GSM_STATUS in
    fi

}


function toggle() {
    debug "toggle GSM modem state using PWRKEY"

    if [ ${WB_GSM_POWER_TYPE} = "2" ]; then
        gpio_set_value $WB_GPIO_GSM_POWER 1
    fi


    gpio_set_value $WB_GPIO_GSM_PWRKEY 0
    sleep 1
    gpio_set_value $WB_GPIO_GSM_PWRKEY 1
    sleep 1
    gpio_set_value $WB_GPIO_GSM_PWRKEY 0
}

function reset() {

    if [ ${WB_GSM_POWER_TYPE} = "1" ]; then
        debug "Resetting GSM modem using RESET pin"
        echo 1 > ${RESET_GPIO}/value
        sleep 0.5
        echo 0 > ${RESET_GPIO}/value
        sleep 0.5
    fi

    if [ ${WB_GSM_POWER_TYPE} = "2" ]; then
        debug "Resetting GSM modem using POWER FET"
        echo 0 > ${POWER_GPIO}/value
        sleep 0.5
        echo 1 > ${POWER_GPIO}/value
        sleep 0.5
    fi

}

function set_speed() {
    stty -F $PORT  115200 -icrnl
}

function init_baud() {
    set_speed
    echo  -e "AAAAAAAAAAAAAAAAAAAT\r\n" > $PORT
    sleep 1
    echo  -e "AT+IPR=115200\r\n" > $PORT
    sleep 1
}

function imei() {
    set_speed
    REPORT_FILE=`mktemp`
    /usr/sbin/chat -s -r $REPORT_FILE  TIMEOUT 2 ABORT "ERROR" REPORT "86" "" "AT+CGSN" OK ""  > $PORT < $PORT
    RC=$?


    if [[ $RC != 0 ]] ; then
        debug "ERROR while getting IMEI"
        rm $REPORT_FILE
        exit $RC;
    fi

    REPORT=`cat $REPORT_FILE | cut -d' ' -f6-`
    rm $REPORT_FILE

    echo $REPORT
}

function imei_sn() {
    IMEI=`imei`
    IMEI_SN=`echo $IMEI | cut -c 9-14`
    echo ${IMEI_SN}
}





function switch_off() {
    debug "Try to switch off GSM modem "

    if [ ${WB_GSM_POWER_TYPE} = "1" ]; then
        debug "resetting GSM modem first"
        reset
        sleep 3
    fi

    debug "Send power down command "
    set_speed
    echo  -e "AT+CPOWD=1\r\n" > $PORT # for SIMCOM
    echo  -e "AT+CPWROFF\r\n" > $PORT # for SIMCOM

    if [ ${WB_GSM_HAS_STATUS_PIN} = "1" ]; then
        debug "Waiting for modem to stop"
        max_tries=25

        for ((i=0; i<=upperlim; i++)); do
            if [ "`gpio_get_value ${WB_GPIO_GSM_STATUS}`" = "0" ]; then
                break
            fi
            sleep 0.2
        done
    else
        sleep 5
    fi

    if [ ${WB_GSM_POWER_TYPE} = "2" ]; then
        debug "physically switching off GSM modem using POWER FET"
        echo 0 > ${POWER_GPIO}/value
    fi;




}


function ensure_on() {
    if [ ${WB_GSM_HAS_STATUS_PIN} = "1" ]; then
        if [ "`gpio_get_value ${WB_GPIO_GSM_STATUS}`" = "1" ]; then
            debug "need to switch off"
            switch_off
        fi
    else
        switch_off
    fi

    if [ ${WB_GSM_POWER_TYPE} = "2" ]; then
        debug "switching on GSM modem using POWER FET"
        echo 1 > ${POWER_GPIO}/value
    fi;

    toggle

    if [ ${WB_GSM_HAS_STATUS_PIN} = "1" ]; then
        debug "Waiting for modem to start"
        max_tries=30

        for ((i=0; i<=upperlim; i++)); do
            if [ "`gpio_get_value ${WB_GPIO_GSM_STATUS}`" = "1" ]; then
                break
            fi
            sleep 0.1
        done
    else
        sleep 2
    fi
    set_speed
}

function test_connection() {
    /usr/sbin/chat   TIMEOUT 5 ABORT "ERROR" ABORT "BUSY" "" ATZ OK "" > $PORT < $PORT
    RC=$?
    echo $RC
}

function restart_if_broken() {
    #~ set_speed
    local RC=0
    if [ ${WB_GSM_HAS_STATUS_PIN} = "1" ]; then
        if [ "`gpio_get_value ${WB_GPIO_GSM_STATUS}`" = "0" ]; then
            debug "Modem switched off, switch it on instead of testing the connection"
            local RC=1
        fi
    fi

    if [[ $RC == 0 ]]; then
        RC=$(test_connection)
        if [[ $RC != 0 ]] ; then
            debug "connection test error!"
        fi
    fi

    if [[ $RC != 0 ]] ; then
        ensure_on
        sleep 5

        RC=$(test_connection)
        if [[ $RC != 0 ]] ; then
            debug "ERROR: modem restarted, still no answer"
            exit $RC;
        fi
    fi
}


function gsm_get_time() {
    #~ set_speed
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

    TIME="${REPORT:8:17}"
    echo $TIME
}


function gsm_set_time() {

    if is_neoway_m660a; then
        TIMESTR="$1";
    else
        TIMESTR="$1+00"
    fi


    REPORT_FILE=`mktemp`
    /usr/sbin/chat -s  TIMEOUT 2 ABORT "ERROR" REPORT "OK" "" "AT+CCLK=\"$TIMESTR\"" OK ""  > $PORT < $PORT
    RC=$?

    if [[ $RC != 0 ]] ; then
        debug "ERROR while setting time"
        exit $RC;
    fi
}







