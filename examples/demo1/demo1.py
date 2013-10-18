#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys, os

from pynfc import *


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


RED='\033[01;31m'
GREEN='\033[01;32m'
NC='\033[0m' # No Color

LED_GPIOS = [32,33,34]

def init_leds():
	for gpio in LED_GPIOS:
		open('/sys/class/gpio/export','wt').write("%d\n" % gpio)
		open('/sys/class/gpio/gpio%d/direction' % gpio,'wt').write("out\n")


def set_led_color(color):
	for i, gpio in enumerate(LED_GPIOS):
		mask = 2 ** i
		if color & mask:
			value = 1
		else:
			value = 0

		open('/sys/class/gpio/gpio%d/value' % gpio,'wt').write("%d\n" % value)



if __name__ == '__main__':
	init_leds()

	nfc = NFC(0) # Select first NFC device
	nfc.powerOn()

	# setup Vin ADC channel
	os.system('/root/utils/adc/adc_set_channel.sh vin')


	prev_result = None

	led_color = 0

	while True:
		# Select card
		c = nfc.selectISO14443A()

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

						led_color = metro_num % 7 + 1
					except:
						print "Error"



			else:
				print "No card in field"
				led_color = 0


			# print voltage
			print "\033[7;1H"

			vin = get_vin()

			if vin < 4.5:
				color = RED
			else:
				color = GREEN

			print "%sVin = %2.1fV, Vbat = %2.1fV%s" % (
				color,
				vin,
				get_vbat(),
				NC
				)

			set_led_color(led_color)


		prev_result = card_result
