# coding: utf-8
import sys
import unittest

from wb_common import wbmqtt
import subprocess
import time
import os.path
from shutil import copyfile
import json
import re

def test():
    return False


class TestADCBase(unittest.TestCase):
    ref_5v = 4.2
    @classmethod
    def setUpClass(cls):
        tmp_conf_fname = '/var/run/shm/adc-test.conf'
        subprocess.call("killall -9 wb-homa-adc", shell=True)

        # turn off averaging and oversampling on each channel
        adc_conf_json = open('/etc/wb-homa-adc.conf').read()
        adc_conf_json = re.sub('//.*', '', adc_conf_json)
        adc_conf = json.loads(adc_conf_json)
        for chan in adc_conf['iio_channels']:
            chan['averaging_window'] = 1
            chan['readings_number'] = 1

        json.dump(adc_conf, open(tmp_conf_fname, 'wt'))
        cls.adc_driver = subprocess.Popen("wb-homa-adc -c %s" % tmp_conf_fname, shell=True)


        cls.wbmqtt = wbmqtt.WBMQTT()
        cls.wbmqtt.watch_device('wb-adc')
        cls.wbmqtt.watch_device('wb-gpio')


    @classmethod
    def tearDownClass(cls):
        cls.wbmqtt.close()
        cls.adc_driver.kill()

    def setUp(self):
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '1')

    def _test_adc_value(self, control, v_ref, delta_percent=1):
        v_measured = self.wbmqtt.get_next_value('wb-adc', control)
        v_measured = float(v_measured)

        self.assertAlmostEqual(v_measured, v_ref, delta=v_ref * delta_percent / 100.0)

    def _adc_assert_less(self, adc_control, v_max, tries=3):
        for i in xrange(tries):
            v_measured = float(self.wbmqtt.get_next_value('wb-adc', adc_control))
            if v_measured < v_max:
                break
        self.assertLess(v_measured, v_max)

    def _adc_assert_greater(self, adc_control, v_min, tries=3):
        for i in xrange(tries):
            v_measured = float(self.wbmqtt.get_next_value('wb-adc', adc_control))
            if v_measured > v_min:
                break
        self.assertGreater(v_measured, v_min)

    def _test_a1a4(self, fet_control, di_control, adc_control):
        self.wbmqtt.send_and_wait_for_value('wb-gpio', fet_control, '1')

        v_max = 0.20  # V

        self._adc_assert_less(adc_control, v_max, tries=3)

        di_state = bool(int(self.wbmqtt.get_last_value('wb-gpio', di_control)))
        self.assertFalse(di_state)


        self.wbmqtt.send_and_wait_for_value('wb-gpio', fet_control, '0')

        self._test_adc_value(adc_control, self.ref_5v, 4)

        di_state = bool(int(self.wbmqtt.get_last_value('wb-gpio', di_control)))
        self.assertTrue(di_state)

    def test_A1(self):
        self._test_a1a4('A1_OUT', 'A1_IN', 'A1')

    def test_A2(self):
        self._test_a1a4('A2_OUT', 'A2_IN', 'A2')

    def test_A3(self):
        self._test_a1a4('A3_OUT', 'A3_IN', 'A3')

    def test_A4(self):
        self._test_a1a4('A4_OUT', 'A4_IN', 'A4')

    def test_Vin(self):
        self._test_adc_value('Vin', 12.0, 20)

    def test_4V(self):
        self._test_adc_value('BAT', 3.9, 5)

    def test_r1(self):
        self._test_adc_value('R1', 10000., 10)


class TestADC52(TestADCBase):

    def test_r2(self):
        self._test_adc_value('R2', 10000., 5)

    def test_5vout(self):
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '0')
        time.sleep(500E-3)
        di_state = bool(int(self.wbmqtt.get_last_value('wb-gpio', 'A1_IN')))
        self.assertFalse(di_state)
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '1')
        time.sleep(10E-3)

class TestADC55(TestADCBase):
    def setUp(self):
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '1')
        v5_val_str = self.wbmqtt.get_next_value('wb-adc', '5Vout')
        if v5_val_str == "nan":
            self.ref_5v = 5.0
            print "Cannot read 5V reference, use default"
        else:
            self.ref_5v = float(v5_val_str)

    def test_5vout(self):
        self.wbmqtt.send_and_wait_for_value('wb-gpio', '5V_OUT', '0')

        self._adc_assert_less('5Vout', 3.0, tries=3)

        self.wbmqtt.send_and_wait_for_value('wb-gpio', '5V_OUT', '1')
        self._adc_assert_less('5Vout', 5.6)
        self._adc_assert_greater('5Vout', 4.8)

if __name__ == '__main__':
    print "Usage: python %s [TestADC52|TestADC55]" % sys.argv[0]
    #~ cal = AdcCalibrate()
    #~ print "r1 constants for R1 and R2 channels:", cal.get_r1_calib(), cal.get_r2_calib()

    unittest.main()
