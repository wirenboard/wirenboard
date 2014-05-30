#!/bin/sh

PWM_NUM=2
PWM_DIR=/sys/class/pwm/pwmchip0/pwm${PWM_NUM}

if [ ! -d "$PWM_DIR" ]; then
    echo 2 > /sys/class/pwm/export
fi;


echo 0 > ${PWM_DIR}/enable
echo 250000 > ${PWM_DIR}/period
echo 125000 > ${PWM_DIR}/duty_cycle

for i in 0 1 2; do
    sleep 0.1;
    echo 1 > ${PWM_DIR}/enable
    sleep 0.1;
    echo 0 > ${PWM_DIR}/enable
done;

echo 0 > ${PWM_DIR}/enable


