#~ from auth import xor_str
import pynfc

from binascii import hexlify, unhexlify

# mifare diversification

# as of MFRC171
#~ def mifare_diversification_8bit_get_enc_input(mifare_key, serial, block):
	#~ assert len(mifare_key) == 6
	#~ assert len(serial) >= 4
	#~ assert 0 <= block <= 255
	#~ serial = serial[-4:]
#~
	#~ load = mifare_key[:4] + \
		   #~ xor_str(mifare_key[4], serial[0]) + \
		   #~ xor_str(mifare_key[5], serial[1]) + \
		   #~ xor_str(chr(block), serial[2]) + \
		   #~ serial[3]
#~
	#~ return load
#~
#~ def mifare_diversification_8bit_get_key(enc_data):
	#~ assert len(enc_data) == 8
	#~ return enc_data[1:7]



def mifare_authenticate(nfc, card, addr, key, useA = True):
	if useA:
		cmd = 0x60
	else:
		cmd = 0x61

	apdu = chr(cmd) + chr(addr) + key + unhexlify(card.uid)[-4:]
	result =  nfc.sendAPDU([hexlify(apdu)])
	if not result[0]:
		raise RuntimeError('Error %d' % result[1])


def mifare_read_sector_authentificated(nfc, addr):
	apdu = '\x30' + chr(addr )
	result = nfc.sendAPDU([hexlify(apdu)])
	if not result[0]:
		raise RuntimeError('Error %d' % result[1])
	return unhexlify(result[1])

def mifare_read_block(nfc, card, addr, key, useA = True, trailer = False):
	mifare_authenticate(nfc, card, addr, key, useA)

	# Read 3 sectors
	data = ''

	for i in xrange(4 if trailer else 3):
		data += mifare_read_sector_authentificated(nfc, addr + i)

	return data

def mifare_write_sector_authenticated(nfc, addr, data):
	assert len(data) == 16
	apdu = '\xA0' + chr(addr)  + data
	result = nfc.sendAPDU([hexlify(apdu)])
	if not result[0]:
		raise RuntimeError('Error %d' % result[1])

def mifare_write_sector(nfc, card, addr, key, data, useA = True):
	mifare_authenticate(nfc, card, addr, key, useA)
	mifare_write_sector_authenticated(nfc, addr, data)

def mifare_write_block(nfc, card, addr, key, data, useA = True, trailer = False):
	mifare_authenticate(nfc, card, addr, key, useA)

	for i in xrange(4 if trailer else 3):
		mifare_write_sector_authenticated(nfc, addr + i, data[i * 16 : (i+1) * 16])






if __name__ == '__main__':
	nfc = pynfc.NFC(0)
	card =  nfc.selectISO14443A()
	print card

	data =  mifare_read_block(nfc, card, 0x04, unhexlify('d3e6afe6677c'))
	print hexlify(data)
	data =  mifare_write_sector(nfc, card, 0x04, unhexlify('d3e6afe6677c'), '\x02' * 16)

	#~ data =  mifare_read_block(nfc, card, 0x34, '\xa0\xa1\xa2\xa3\xa4\xa5') + mifare_read_block(nfc, card, 0x34+4, '\xa0\xa1\xa2\xa3\xa4\xa5')
