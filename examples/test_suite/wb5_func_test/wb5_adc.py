# coding: utf-8
import unittest

import sys
sys.path.insert(0, "../common")

import wbmqtt
import subprocess
import time


def test():
    return False


class TestADC(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.call("service wb-homa-adc start", shell=True)

        #~ cls.adc = adc.ADC()
        cls.wbmqtt = wbmqtt.WBMQTT()

    @classmethod
    def tearDownClass(cls):
        cls.wbmqtt.close()

    def setUp(self):
        #~ self.adc.set_scale(0, self.adc.get_available_scales(0)[1])
        #~ self.adc.set_scale(1, self.adc.get_available_scales(1)[1])

        #~ self.wbmqtt.clear_values()
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '1')

    def _test_adc_value(self, control, v_ref, delta_percent=1):
        v_measured = self.wbmqtt.get_next_value('wb-adc', control)
        v_measured = float(v_measured)

        self.assertAlmostEqual(v_measured, v_ref, delta=v_ref * delta_percent / 100.0)

    def _test_a1a4(self, fet_control, di_control, adc_control):
        self.wbmqtt.send_value('wb-gpio', fet_control, '1')
        time.sleep(500E-3)

        v_max = 0.20  # V
        v_measured = float(self.wbmqtt.get_next_value('wb-adc', adc_control))
        self.assertLess(v_measured, v_max)

        di_state = bool(int(self.wbmqtt.get_last_value('wb-gpio', di_control)))
        self.assertFalse(di_state)

        self.wbmqtt.send_value('wb-gpio', fet_control, '0')
        time.sleep(2000E-3)
        self._test_adc_value(adc_control, 4.80, 4)

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

    def test_5vout(self):
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '0')
        time.sleep(500E-3)
        di_state = bool(int(self.wbmqtt.get_last_value('wb-gpio', 'A1_IN')))
        self.assertFalse(di_state)
        self.wbmqtt.send_value('wb-gpio', '5V_OUT', '1')
        time.sleep(10E-3)

    def test_Vin(self):
        self._test_adc_value('Vin', 12.0, 20)

    def test_4V(self):
        self._test_adc_value('BAT', 3.9, 5)

    def test_r1(self):
        self._test_adc_value('R1', 10000., 5)

    def test_r2(self):
        self._test_adc_value('R2', 10000., 5)


if __name__ == '__main__':
    #~ cal = AdcCalibrate()
    #~ print "r1 constants for R1 and R2 channels:", cal.get_r1_calib(), cal.get_r2_calib()

    unittest.main()
