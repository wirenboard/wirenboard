# coding: utf-8
import unittest

import os

import sys
sys.path.insert(0, "../common")

import time
import wbmqtt
import subprocess


class TestFETs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.call("service wb-homa-adc start", shell=True)

        #~ cls.adc = adc.ADC()
        cls.wbmqtt = wbmqtt.WBMQTT()

    @classmethod
    def tearDownClass(cls):
        cls.wbmqtt.close()

    def setUp(self):
        self.wbmqtt.clear_values()


if __name__ == '__main__':
    unittest.main()
