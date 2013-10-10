#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys, os

from pynfc import *

import binascii
def read_ultralight(n):
	hex_data = ''

	for i in xrange(4):
		status, data = n.sendAPDU(['30', hex(i * 4)[2:].zfill(2)])
		hex_data += data

	return hex_data

def read_metro_classic(n):
	""" Read public data from russian "social cards" """
	# TODO: use high level functions

	# Authentificate block using keyA = a0a1a2a3a4a5
	n.sendAPDU(['6034a0a1a2a3a4a5fb1d3656'])

	# Read 3 sectors
	data = ''
	data+= n.sendAPDU(['3034'])[1]
	data+= n.sendAPDU(['3035'])[1]
	data+= n.sendAPDU(['3036'])[1]


	# Another block
	n.sendAPDU(['6038a0a1a2a3a4a5fb1d3656'])
	data+= n.sendAPDU(['3038'])[1]
	data+= n.sendAPDU(['3039'])[1]
	data+= n.sendAPDU(['303a'])[1]


	print data
	# decode cp1251-coded holder's name
	name1 =  binascii.unhexlify(data[2:70]).decode('cp1251')
	name2 = binascii.unhexlify(data[98:]).decode('cp1251')

	return name1, name2


if __name__ == '__main__':

	nfc = NFC(0) # Select first NFC device
	nfc.powerOn()

	while True:
		# Select card
		c = nfc.selectISO14443A()

		if c:
			print "Selected card: ", c

			print "UID:", c.uid
			print "ATR:", c.atr
			print "ATQA:", c.atqa

			if c.atqa == '0044':
				print "Found Mifare Ultralight card"
				ul_data = read_ultralight(nfc)

				print "Hex data: " + ul_data

				print 'Moscow Metro UL number: ' + str(int(ul_data[37:45], 16))

			elif c.atqa == '0002':
				print "Found Mifare Classic card"

				name1, name2 = read_metro_classic(nfc)
				print ("Name: " + name1 + name2).encode('utf8')



		else:
			print "No card present "


		raw_input(">>>Press control-C to exit, any other key to repeat")

