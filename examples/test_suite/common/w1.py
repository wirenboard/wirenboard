# coding: utf-8
import unittest

import os

def test():
	return False



class TestW1(unittest.TestCase):
    def setUp(self):
        pass

    def test_presense(self):
        entries = os.listdir("/sys/bus/w1/devices/")
        devices = [x for x in entries if ('-' in x)]

        self.assertTrue(bool(devices ))


