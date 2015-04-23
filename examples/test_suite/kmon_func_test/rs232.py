# coding: utf-8
import unittest

import os
import serial
import time


class _TestRS232_Base(unittest.TestCase):
    port = None

    def setUp(self):
        assert self.port is not None
        self.ser = serial.Serial(self.port, 19200, timeout=3)
        self.ser.flush()
        self.ser.flushInput()
        self.ser.flushOutput()

    def test_echo(self):
        time.sleep(200E-3)
        data_to_write = '1234\n'

        self.ser.write(data_to_write)
        self.ser.flush()
        time.sleep(1)
        data = self.ser.readline()
        self.ser.close()

        self.assertEqual(data, data_to_write, " %s RS232 ERROR\nTransmitted %s\nReceived: %s"  % (self.port, data_to_write, data))

    def tearDown(self):
        self.ser.close()

class TestRS232Front(_TestRS232_Base):
    port = '/dev/ttyNSC2'

class TestRS232Back(_TestRS232_Base):
    port = '/dev/ttyNSC3'





if __name__ == '__main__':
    suite = unittest.TestSuite()

    suite.addTest(unittest.makeSuite(TestRS232Back))
    suite.addTest(unittest.makeSuite(TestRS232Front))



    unittest.TextTestRunner(verbosity=2).run(suite)


