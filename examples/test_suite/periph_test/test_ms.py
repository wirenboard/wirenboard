import unittest
from collections import OrderedDict
import sys
import os
import datetime
import hashlib
import time
import subprocess
sys.path.insert(0, "../common")

import argparse
import tempfile
import json

    
import leds
import beeper
from wbmqtt import WBMQTT


from test_ms_common import TestCO2, TestBuzzer, TestIlluminance, TestSPL, TestTH, TestHStrict, TestEEPROMPersistence, MSTesterBase, Test1Wire
from periph_common import parse_comma_separated_set, SerialDeviceHandler, SerialDriverHandler, ModbusDeviceTestLog, get_wbmqtt
import periph_common


class TestIlluminanceMS(TestIlluminance):
    MAX_AMBIENT = 50
    ILLUMINATED_DIFF =  4970
    ILLUMINATED_DIFF_ERR = 0.07

class TestSPLMS(TestSPL):
    SOUND_LEVEL_MIN = 72.7
    SOUND_LEVEL_MAX = 79.6
    AMBIENT_MAX = 63


class Tester(MSTesterBase):
    MQTT_DEVICE_ID = 'wbms-test'
    CONFIG_FNAME = "wbms.conf"
    def init_mapping(self):
        self.mapping = OrderedDict([
                (TestSPLMS, 2),
                (TestIlluminanceMS, 3),
                (TestTH, 4),
                (TestHStrict, 8),
                (Test1Wire, 7),
                (TestEEPROMPersistence, 1),
        ])



if __name__ == '__main__':
    while 1:
        try:
            periph_common.get_wbmqtt().watch_device('am2320')
            Tester().main()
        finally:
            periph_common.get_wbmqtt().close()

        while 1:
            e = raw_input("press Enter to continue or Control+C to exit")
            if e == '':
                break

        print "\n" * 5



