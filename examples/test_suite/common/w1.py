# coding: utf-8
import unittest

import os

def test():
	return False



class TestW1(unittest.TestCase):
    NUMBER_REQUIRED = 1
    def setUp(self):
        pass

    def test_presense(self):
        entries = os.listdir("/sys/bus/w1/devices/")
        devices = [x for x in entries if ('-' in x)]

        self.assertEquals(len(devices), self.NUMBER_REQUIRED)


