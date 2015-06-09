#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys, os
import time
from pynfc import *
from threading import Thread
RED='\033[01;31m'
GREEN='\033[01;32m'
NC='\033[0m' # No Color


import os
import time


pwm_num = 2
pwm_dir = '/sys/class/pwm/pwmchip0/pwm' + str(pwm_num)

def beeper_setup():


    if not os.path.exists(pwm_dir):
        open('/sys/class/pwm/pwmchip0/export', 'w').write(str(pwm_num) + '\n')


    open(pwm_dir + '/enable', 'w').write('0\n')
    open(pwm_dir + '/period', 'w').write('250000\n')
    open(pwm_dir + '/duty_cycle', 'w').write('125000\n')


def beeper_on():
    open(pwm_dir + '/enable', 'w').write('1\n')

def beeper_off():
    open(pwm_dir + '/enable', 'w').write('0\n')



def read_adc_channel(channel):
    n_times = 10
    raw_sum = 0
    for i in xrange(n_times):
        raw = int(open('/sys/bus/iio/devices/iio:device0/in_voltage%d_raw' % channel).read())
        raw_sum += raw

    raw_mean = float(raw_sum)  / n_times

    return raw_mean / 4096. * 1.85


def get_vin():
    return read_adc_channel(1) * 7.061

def get_vbat():
    return read_adc_channel(7) * 4


def read_ultralight(n):
    hex_data = ''

    for i in xrange(4):
        status, data = n.sendAPDU(['30', hex(i * 4)[2:].zfill(2)])
        hex_data += data

    return hex_data


#~ BUZZER = 32

LOCK_GPIO = 52
EXIT_BUTTON_GPIO = 38

def export_gpio(gpio):
    open('/sys/class/gpio/export','wt').write("%d\n" % gpio)

def gpio_set_direction(gpio, direction):
    open('/sys/class/gpio/gpio%d/direction' % gpio,'wt').write(direction + "\n")

def init_gpios():
    for gpio in (LOCK_GPIO,):
        export_gpio(gpio)
        gpio_set_direction(gpio, "out")


    for gpio in (EXIT_BUTTON_GPIO,):
        export_gpio(gpio)
        gpio_set_direction(gpio, "in")


def gpio_set_value(gpio, value):
    open('/sys/class/gpio/gpio%d/value' % gpio,'wt').write("%d\n" % value)

def gpio_get_value(gpio):
    return bool(int(open('/sys/class/gpio/gpio%d/value' % gpio).read().strip()))

def led_set_brightness(led, value):
    open('/sys/class/leds/%s/brightness' % led,'wt').write("%d\n" % value)


def handle_exit_button():
    while True:
        #~ print "handle_exit_button iter"
        value = gpio_get_value(EXIT_BUTTON_GPIO)
        if not value:
            grant_access()

        time.sleep(1)


def grant_access():
    """ Opens lock for a couple of seconds"""
    print "grant access"

    led_set_brightness('red', 0)
    led_set_brightness('green', 1)
    beeper_on()

    gpio_set_value(LOCK_GPIO, 0) # open lock

    time.sleep(0.5)
    beeper_off()


    time.sleep(3)
    gpio_set_value(LOCK_GPIO, 1) # close lock
    led_set_brightness('green', 0)
    led_set_brightness('red', 1)



if __name__ == '__main__':
    init_gpios()
    beeper_setup()

    #~ exit_button_thread = Thread(target = handle_exit_button)
    #~ exit_button_thread.daemon = True
    #~ exit_button_thread.start()

    nfc = NFC(0) # Select first NFC device
    nfc.powerOn()


    prev_result = None

    led_color = 0
    led_set_brightness('red', 1)
    led_set_brightness('green', 0)
    beeper_off()

    gpio_set_value(LOCK_GPIO, 1)



    while True:
        # Select card
        c = nfc.selectISO14443A()
        access_granted = False

        card_result = c.uid if c else None

        if card_result != prev_result:
            print "\033c"
            if c:
                print GREEN + "Card: " + NC + "[%s] %s" % (c.atqa, c.uid)

                if c.atqa == '0044':
                    print "Found Mifare Ultralight card"
                    try:
                        ul_data = read_ultralight(nfc)
                        metro_num = int(ul_data[37:45], 16)
                        print 'Metro UL card: ' + RED + str(metro_num) + NC


                        if (metro_num % 2 == 0):
                            access_granted = True



                    except:
                        print "Error"



                if access_granted:
                    print "access granted"
                    grant_access()

                    print "end"
                else:


                    for i in xrange(3):
                        beeper_on()
                        led_set_brightness('red', 1)
                        time.sleep(0.1)
                        beeper_off()
                        led_set_brightness('red', 0)
                        time.sleep(0.1)
                    led_set_brightness('red', 1)
                    beeper_off()


            else:
                print "No card in field"
                led_color = 0



        prev_result = card_result
