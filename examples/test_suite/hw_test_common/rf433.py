# coding: utf-8
import unittest

import subprocess
import os
import re
import sys



import sys
import time
from functools import wraps
import errno
import os
import signal

class TimeoutError(Exception):
    pass

class Timeout:
    def __init__(self, seconds=1, error_message='Timeout'):
        self.seconds = seconds
        self.error_message = error_message
    def handle_timeout(self, signum, frame):
        raise TimeoutError(self.error_message)
    def __enter__(self):
        signal.signal(signal.SIGALRM, self.handle_timeout)
        signal.alarm(self.seconds)
    def __exit__(self, type, value, traceback):
        signal.alarm(0)


class TestRFM69(unittest.TestCase):
    SPI_MINOR = 4
    SPI_MAJOR = 0
    IRQ_GPIO = 92
    @classmethod
    def setUpClass(cls):
        sys.path.append('/usr/lib/wb-homa-ism-radio/')
        import rfm69
        sys.path.remove('/usr/lib/wb-homa-ism-radio/')

        subprocess.call("/etc/init.d/wb-homa-ism-radio stop", shell=True)


        spi_minor = 4
        irq_gpio = 92
        cls.radio = rfm69.RFM69(spi_major = cls.SPI_MAJOR, spi_minor=cls.SPI_MINOR,irq_gpio=cls.IRQ_GPIO)



    def setUp(self):
        pass


    def test_temperature(self):

        temp = None
        with Timeout(seconds=10):
            self.radio.config()
            temp = self.radio.readTemperature(0)

            print "temp=", temp

        self.assertLessEqual(temp, 55)
        self.assertGreaterEqual(temp, 21)



if __name__ == '__main__':
    unittest.main()

