import os

SYS_PREFIX='/sys/class/leds/'

def set_brightness(led, val):
    open(SYS_PREFIX  + led + '/brightness', 'wt').write(str(val) + '\n')

def set_blink(led, delay_on=100, delay_off=100):
    open(SYS_PREFIX  + led + '/trigger', 'wt').write('timer\n')

    open(SYS_PREFIX  + led + '/delay_on', 'wt').write(str(delay_on) + '\n')
    open(SYS_PREFIX  + led + '/delay_off', 'wt').write(str(delay_off) + '\n')
    set_brightness(led, 1)

def blink_fast(led):
    set_blink(led, 50, 50)

