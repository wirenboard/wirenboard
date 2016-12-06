# coding: utf-8
import unittest

import os
import serial
import time


class _TestRS232_Base(unittest.TestCase):
    port = None
    BAUDRATE = 19200

    def setUp(self):
        assert self.port is not None
        self.ser = serial.Serial(self.port, self.BAUDRATE, timeout=3)
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
