#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys, os
import binascii
import datetime

from pynfc import *
from mifare import *

def read_ultralight(n):
	hex_data = ''

	for i in xrange(4):
		status, data = n.sendAPDU(['30', hex(i * 4)[2:].zfill(2)])
		hex_data += data

	return hex_data


def decode_bcd(s, count=None):
	result = ''
	for b in s:
		result += hex(ord(b))[2:].zfill(2)
	return result[:count]


def read_metro_classic(n, card):
	""" Read public data from russian "social cards" """

	keyA = '\xa0\xa1\xa2\xa3\xa4\xa5'
	sector =  mifare_read_block(nfc, card, 4 * 13, keyA)
	sector +=  mifare_read_block(nfc, card, 4 * 14, keyA)

	sector15 =  mifare_read_block(nfc, card, 4 * 15, keyA)


	last_name = sector[1:34].decode('cp1251').strip()
	sex = sector[36]

	birthday_str = sector[39:39+8]
	birthday = datetime.date( int(birthday_str[:4]),  int(birthday_str[4:6]),  int(birthday_str[6:8]))

	first_name = sector[49:49+46].strip().decode('cp1251').strip()

	card_number = decode_bcd(sector15[1:11],19)
	card_series = decode_bcd(sector15[11:15],8)

	return last_name, first_name, sex, birthday, card_number, card_series




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

				last_name, first_name, sex, birthday, card_number, card_series = read_metro_classic(nfc, c)
				print ("Name: " + last_name + ' ' + first_name).encode('utf8')
				print (u"card number: %s, card series: %s, sex: %s, birthday: %s" % (card_number, card_series, sex, birthday)).encode('utf8')



		else:
			print "No card present "


		#~ raw_input(">>>Press control-C to exit, any other key to repeat")

