# coding: utf-8
import unittest
import rs232

class TestUSBSerialData(rs232._TestRS232_Base):
    BAUDRATE = 115200
    port = '/dev/ttyUSB0'

if __name__ == '__main__':
    unittest.main()