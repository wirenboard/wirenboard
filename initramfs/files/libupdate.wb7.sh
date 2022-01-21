#!/bin/bash

POWER_BUTTON_GPIO=110
PWM_BUZZER=1

# 3 kHz, 50% volume
DUTY_CYCLE=166666
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
    echo $POWER_BUTTON_GPIO > /sys/class/gpio/export 2>/dev/null || true
}

button_read() {
    cat /sys/class/gpio/gpio${POWER_BUTTON_GPIO}/value
}

button_up() {
    [ `button_read` == 1 ]
}

button_down() {
    [ `button_read` == 0 ]
}
