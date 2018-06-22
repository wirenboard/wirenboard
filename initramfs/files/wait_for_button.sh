#!/bin/bash

# Time to wait for button press in seconds
WAIT_TIME=${WAIT_TIME:-10}

# Time to hold button
HOLD_TIME=${HOLD_TIME:-4}

# Buzzer use flag
USE_BUZZER=${USE_BUZZER:-y}

# Use echo output to display progress
USE_ECHO=${USE_ECHO:-y}

# Loop tick delay in seconds
TICK_DELAY=0.2

# Tick multiplier is 1/TICK_DELAY
TICK_MUL=5

use_buzzer() {
    [ "x${USE_BUZZER}" == "xy" ]
}

LIBS_PATH=/lib/
DT_COMPAT_LIST=`tr < /proc/device-tree/compatible '\000' '\n'`

for compat in $DT_COMPAT_LIST; do
    case "$compat" in
        "contactless,imx28-wirenboard50" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard52" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard55" )
            LIB=wb5
            break
            ;;
        "contactless,imx28-wirenboard58" )
            LIB=wb5
            break
            ;;
        "contactless,imx6ul-wirenboard60" )
            LIB=wb6
            break
            ;;
        "contactless,imx6ul-wirenboard61" )
            LIB=wb6
            break
            ;;
    esac
done

source ${LIBS_PATH}/libupdate.${LIB}.sh || {
    echo "Unknown platform"
    exit 1
}

if [ "x${USE_ECHO}" == "xy" ]; then
    _ECHO_COUNTER=0
    echo_progress() {
        _ECHO_COUNTER=$((_ECHO_COUNTER + 1))
        if [ $_ECHO_COUNTER -eq $TICK_MUL ]; then
            echo -n $1
            _ECHO_COUNTER=0
        fi
    }
    
    echo_reset() {
        echo
    }
else
    echo_progress() {
        true
    }

    echo_reset() {
        true
    }
fi


if use_buzzer; then
    buzzer_init

    buzzer_wait() {
        buzzer_on
    }

    _BUZZER_HOLD_COUNTER=0
    buzzer_hold() {
        _BUZZER_HOLD_COUNTER=$((_BUZZER_HOLD_COUNTER + 1))
        if [ $_BUZZER_HOLD_COUNTER -eq $TICK_MUL ]; then
            buzzer_on
            _BUZZER_HOLD_COUNTER=0
        else
            buzzer_off
        fi
    }
fi

button_init

WAIT_TIME_TICKS=$((WAIT_TIME * TICK_MUL))
HOLD_TIME_TICKS=$((HOLD_TIME * TICK_MUL))
HOLD_TIME_CURRENT=$HOLD_TIME_TICKS

# exit code is 1 by default (failed)
RET=1

while [ $WAIT_TIME_TICKS -gt 0 ]; do
    # wait for button to be pressed
    while button_up && [ $WAIT_TIME_TICKS -gt 0 ]; do
        sleep $TICK_DELAY
        echo_progress 'o'
        buzzer_wait
        WAIT_TIME_TICKS=$((WAIT_TIME_TICKS-1))
    done

    if button_up; then
        RET=1
        break
    fi

    # measure time when button is down
    while button_down && [ $HOLD_TIME_CURRENT -gt 0 ]; do
        sleep $TICK_DELAY
        echo_progress '.'
        buzzer_hold
        HOLD_TIME_CURRENT=$((HOLD_TIME_CURRENT-1))
    done

    # check current button state
    if button_down; then
        # button press is correctly completed
        RET=0
        break
    else
        # button press is not completed
        # restore hold timer
        HOLD_TIME_CURRENT=$HOLD_TIME_TICKS
        echo_reset
    fi
done

if use_buzzer; then
    buzzer_off
fi

echo_reset

exit $RET
