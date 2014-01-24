#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys, os
import datetime, time


from pynfc import *


def read_adc_channel_raw(channel):
	n_times = 10
	raw_sum = 0
	for i in xrange(n_times):
		raw = int(open('/sys/bus/iio/devices/iio:device0/in_%s_raw' % channel).read())
		raw_sum += raw

	raw_mean = float(raw_sum)  / n_times

	return raw_mean

def read_adc_channel(channel, prefix = 'voltage'):
	return read_adc_channel_raw('%s%d' % (prefix, channel)) * 1.85 / 4095


def get_vin():
	return read_adc_channel(1) * 7.061


def get_die_temp():
	v1 = read_adc_channel_raw('temp8')
	v2 = read_adc_channel_raw('temp9')

	return (v2 - v1) *  1.012 / 4 - 273.15



import urllib2
import json

def send_log(json_str):
	try:
		log_data = "PLAINTEXT=" + urllib2.quote(json_str)
		urllib2.urlopen("https://logs-01.loggly.com/inputs/4bc69f91-1ed3-43bb-8268-3360d28649ad/tag/python/", log_data)
	except:
		print "error sending log"

def get_uptime():
	with open('/proc/uptime', 'r') as f:
		uptime_seconds = float(f.readline().split()[0])
		return uptime_seconds


	    #~ uptime_string = str(datetime.timedelta(seconds = uptime_seconds))

def get_ext_temp():
	try:
		slave = open('/sys/bus/w1/devices/w1_bus_master1/w1_master_slaves').read().strip()
		if not slave:
			return None


		data = open('/sys/bus/w1/devices/w1_bus_master1/%s/w1_slave' % slave).read()
		data =  data.strip()
		tmp_str = data[data.rfind('=')+1:]

		return int(tmp_str) / 1E3

	except:
		return None

def loop():
	ts = time.time()
	dt_str = str(datetime.datetime.now())
	die_temp = get_die_temp()


	log_data = { 'timestamp' : ts,
	            'uptime'    : get_uptime(),
	            'die_temp'  : die_temp,
	            'ext_temp'  : get_ext_temp(),
	            'lsusb' : lsusb(),
	            'iwlist': iwlist(),
	            'usb_md5': test_usb_read(),
	            'vin' : get_vin(),
	            'nfc' : get_nfc(),

	            'gps' : read_gps(),

	            }



	print log_data


	json_str = json.dumps(log_data)

	send_log(json_str)

	open('/root/test.log','at').write("%s\t%s\n" % (dt_str, json_str))

def lsusb():
	try:
		data = os.popen('lsusb').read()
		devices = []
		for line in data.split('\n'):
			if line:
				vidpid = line[23:32]
				devices.append(vidpid)
		return devices
	except:
		return None

def iwlist():
	try:
		data = os.popen('iwlist wlan0 scan').read()
		addresses = []
		levels = []

		for line in data.split('\n'):
			if line:
				if 'Address' in line:
					addresses.append(line[-18:].strip())
				elif 'Signal level' in line:
					levels.append(line[-8:].strip())


		return [addresses, levels]
	except:
		return None

def test_usb_read():
	try:
		return os.popen('md5sum /mnt/sda1/testfile.10M').read().strip().split()[0]
	except:
		return None


nfc = NFC(0) # Select first NFC device

def get_nfc():
	c = nfc.selectISO14443A()
	card_result = c.uid if c else None
	return card_result

def init():
	global nfc
	os.system('modprobe w1_therm')
	os.system('/etc/init.d/hostapd stop')
	os.system('ifconfig wlan0 up')
	os.system('/opt/utils/adc/adc_set_channel.sh vin')
	os.system('ifconfig wlan0 up')
	os.system('stty -F /dev/ttyNSC1 115200')
	#~ nfc =
	nfc.powerOn()


def read_gps():
	with open('/dev/ttyNSC1') as fd:
		for i in xrange(100):
			line = fd.readline()
			if 'RMC' in line:
				gprmc = line[:-2]

				return gprmc

	return None





if __name__ == '__main__':
	#~ print read_gps()
	init()
	#~ print get_ext_temp()
	while 1:
		loop()
	#~ print get_die_temp()


# http://pywilist.googlecode.com/svn/trunk/IWList.py
