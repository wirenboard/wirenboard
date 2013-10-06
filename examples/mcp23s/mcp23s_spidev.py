OB#!/usr/bin/env python3
import time, struct
from quick2wire.spi import *
from collections import namedtuple

IOCON = 0x05
IODIR = 0x00
IPOL = 0x01
GPINTEN = 0x02
DEFVAL = 0x03
INTCON = 0x04
IOCON = 0x05
GPPU = 0x06
INTF = 0x07
INTCAP = 0x08
GPIO = 0x09
OLAT = 0xA


def writeRegister(registerAddress, data):
	spi0.transaction(writing_bytes(0b01000000, registerAddress, data))




def readRegister(registerAddress):
  response = spi0.transaction(writing_bytes(0b01000001, registerAddress), reading(1))
  #~ print (response[0])
  return ord(response[0])




SPI_MAJOR = 1
SPI_MINOR = int(sys.argv[1])


spi0 = SPIDevice(SPI_MINOR, SPI_MAJOR)


start = spi0.speed_hz
print ("current speed Hz: " + str(start))
spi0.speed_hz = 10000
print ("New speed Hz: " + str(spi0.speed_hz))
#~ #~
# Toggle the clock mode
mode = spi0.clock_mode
print ("clock mode before = %i" % spi0.clock_mode)
spi0.clock_mode = (mode ^ SPI_MODE_0) & SPI_MODE_0
print ("clock mode after = %i" % spi0.clock_mode)




writeRegister(IOCON, 0b00100100) # // access EFR register

print (readRegister(IOCON))

print (readRegister(IODIR))
print (readRegister(IOCON))
print (readRegister(IODIR))
print (readRegister(IPOL))
print (readRegister(GPINTEN))
print (readRegister(DEFVAL))
print (readRegister(INTCON))
print (readRegister(IOCON))
print (readRegister(GPPU))
print (readRegister(INTF))
print (readRegister(INTCAP))
print (readRegister(GPIO))
print (readRegister(OLAT))



writeRegister(IODIR, 0xff)
writeRegister(GPPU, 0xff)

while 1:
	time.sleep(1)
	print (bin(readRegister(GPIO))[2:].zfill(8))



from quick2wire.spi_ctypes import *
