# coding: utf-8
import unittest

from wb_common import wbmqtt
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
