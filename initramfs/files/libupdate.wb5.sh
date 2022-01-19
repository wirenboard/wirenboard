#!/bin/bash

PWM_BUZZER=3

# 3 kHz, 10% volume
DUTY_CYCLE=33333
PERIOD=333333

buzzer_init() {
    echo $PWM_BUZZER > /sys/class/pwm/pwmchip0/export 2>/dev/null

    local r1=1
    local r2=1
    while [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; do
        echo $DUTY_CYCLE > /sys/class/pwm/pwmchip0/pwm${PWM_BUZZER}/duty_cycle 2>/dev/null
        r1=$?

        echo $PERIOD > /sys/class/pwm/pwmchip0/pwm${PWM_BUZZER}/period 2>/dev/null
        r2=$?
    done
}

buzzer_on() {
    echo 1 > /sys/class/pwm/pwmchip0/pwm${PWM_BUZZER}/enable
}

buzzer_off() {
    echo 0 > /sys/class/pwm/pwmchip0/pwm${PWM_BUZZER}/enable
}

button_init() {
    true
}

button_read() {
    memdump 0x800440c2 1 | od -t x1 -A n | dd bs=1 skip=1 count=1 2>/dev/null
}

button_up() {
    [ `button_read` == 1 ]
}

button_down() {
    [ `button_read` == 3 ]
}
