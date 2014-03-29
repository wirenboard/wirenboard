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


from mifare import *

def read_metro_classic(n, card):
	""" Read public data from russian "social cards" """

	keyA = '\xa0\xa1\xa2\xa3\xa4\xa5'
	data =  mifare_read_block(nfc, card, 4 * 13, keyA)
	data +=  mifare_read_block(nfc, card, 4 * 14, keyA)

	#~ print data
	# decode cp1251-coded holder's name
	name1 =  data[1:34].decode('cp1251').strip()
	name2 = data[49:-1].decode('cp1251').strip()


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

			elif c.atqa == '0002' or c.atqa == '0004':
				print "Found Mifare Classic card"

				name1, name2 = read_metro_classic(nfc, c)
				print ("Name: " + name1 + ' ' + name2).encode('utf8')



		else:
			print "No card present "


		#~ raw_input(">>>Press control-C to exit, any other key to repeat")

