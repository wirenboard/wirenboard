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

from test_ms_common import TestCO2, TestBuzzer, TestIlluminance, TestSPL, TestTH, TestHStrict, TestEEPROMPersistence, parse_comma_separated_set, SerialDeviceHandler, SerialDriverHandler, ModbusDeviceTestLog, MSTesterBase, Test1Wire
import test_ms_common





class TestIlluminanceMSW2(TestIlluminance):
    MAX_AMBIENT = 50
    ILLUMINATED_DIFF = 4390
    ILLUMINATED_DIFF_ERR = 0.08

class TestSPLMSW(TesterstSPL):
    SOUND_LEVEL_MIN = 75.4
    SOUND_LEVEL_MAX = 81.5
    AMBIENT_MAX = 63



class Tester(MSTesterBase):
    MQTT_DEVICE_ID = 'wbmsw2-test'
    CONFIG_FNAME = "wbmsw2.conf"

    def init_mapping(self):
        self.mapping = OrderedDict([
                (TestSPLMSW, 2),
                (TestIlluminanceMSW2, 3),
                (TestTH, 4),
                (TestHStrict, 8),
                (TestCO2, 5),
                (TestBuzzer, 6),
                (TestEEPROMPersistence, 1),
        ])




if __name__ == '__main__':
    while 1:
        try:
            test_ms_common.wbmqtt = WBMQTT()
            wbmqtt = test_ms_common.wbmqtt
            wbmqtt.watch_device('am2320')
            Tester().main()
        finally:
            wbmqtt.close()

        while 1:
            e = raw_input("press Enter to continue or Control+C to exit")
            if e == '':
                break

        print "\n" * 5



