# coding: utf-8
import unittest
from rs232 import _TestRS232_Base

class TestRS232Front(_TestRS232_Base):
    BAUDRATE = 19200
    port = '/dev/ttyNSC2'

class TestRS232Back(_TestRS232_Base):
    BAUDRATE = 19200
    port = '/dev/ttyNSC3'


if __name__ == '__main__':
    suite = unittest.TestSuite()

    suite.addTest(unittest.makeSuite(TestRS232Back))
    suite.addTest(unittest.makeSuite(TestRS232Front))



    unittest.TextTestRunner(verbosity=2).run(suite)


