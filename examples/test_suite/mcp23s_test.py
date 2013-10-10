#!/usr/bin/env python3
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
  return ord(response[0])

SPI_MAJOR = 1
SPI_MINOR = 5

spi0 = SPIDevice(SPI_MINOR, SPI_MAJOR)

spi0.speed_hz = 1000000
mode = spi0.clock_mode
spi0.clock_mode = (mode ^ SPI_MODE_0) & SPI_MODE_0

writeRegister(IOCON, 0b00100100) # // access EFR register
assert (readRegister(IOCON) == 0b00100100)

for val in range(4):
	writeRegister(IODIR, val)
	assert (readRegister(IODIR) == val)


