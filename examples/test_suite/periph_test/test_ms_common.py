import unittest
from collections import OrderedDict
import sys
import os
import datetime
import hashlib
import time
import subprocess

sys.path.insert(0, "../common")

from periph_common import PeriphTesterBase, get_wbmqtt
import periph_common


class AM2320ReferenceMixin(object):
    @classmethod
    def _set_reference_humidity(cls):
        cls.reference_humidity = float(periph_common.get_wbmqtt().get_last_or_next_value('am2320', 'humidity'))
    @classmethod
    def _set_reference_temperature(cls):
        cls.reference_temperature = float(periph_common.get_wbmqtt().get_last_or_next_value('am2320', 'temperature'))


class TestTH(unittest.TestCase, AM2320ReferenceMixin):
    @classmethod
    def setUpClass(cls):
        cls._set_reference_temperature()
        cls._set_reference_humidity()

    def test_humidity(self):
        value = periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'Humidity')
        print "Humidity: %s" % value

        if value is None:
            self.__class__.last_humidity = None
        else:
            self.__class__.last_humidity = float(value)

        self.assertIsNotNone(value)
        self.assertAlmostEqual(float(value), self.reference_humidity, delta = 7)

    def test_temperature(self):
        value = periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'Temperature')
        print "Temperature: %s" % value
        self.assertIsNotNone(value)

        self.assertAlmostEqual(float(value), self.reference_temperature, delta = 1.5)

    def test_error_count(self):
        while True:
            am2320_reads = int(periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'AM2320 reads'))
            if am2320_reads < 5:
                continue

            am2320_errors = int(periph_common.get_wbmqtt().get_last_or_next_value(periph_common.serial_device.device_id, 'AM2320 errors'))
            self.assertLess(am2320_errors, am2320_reads / 2 + 1)

            return

class TestHStrict(unittest.TestCase, AM2320ReferenceMixin):
    @classmethod
    def setUpClass(cls):
        cls._set_reference_humidity()

    def test_humidity_strict(self):
        value = periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'Humidity')
        print "Humidity: %s" % value

        self.assertIsNotNone(value)
        self.assertAlmostEqual(float(value), self.reference_humidity, delta = 3)

class Test1Wire(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference_temperature = float(periph_common.get_wbmqtt().get_last_or_next_value('am2320', 'temperature'))

    def _test_1wire_temp(self, channel):
        assert 1 <= channel <= 2
        value = periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'External Sensor %d' % channel, timeout=2)
        print "Ext. sensor %d Temperature: %s" % (channel, value)
        self.assertIsNotNone(value)

        self.assertAlmostEqual(float(value), self.reference_temperature, delta = 7)

    def test_ext1(self):
        self._test_1wire_temp(1)

    def test_ext2(self):
        self._test_1wire_temp(2)

class TestSPL(unittest.TestCase):
    AMBIENT_MAX = 63
    @classmethod
    def setUpClass(cls):
        periph_common.serial_device.serial_driver.ensure_running()

    def test_ambient(self):
        time.sleep(200E-3)
        spl_value = periph_common.get_wbmqtt().get_average_value(periph_common.serial_device.device_id, 'Sound Level', interval=2)
        print ("Ambient value: %s" % spl_value)
        self.assertIsNotNone(spl_value)
        self.assertLess(float(spl_value), self.AMBIENT_MAX)

    def test_s600hz(self):
        #sox -n -r 44100 600hz_0.01_10s.wav  synth 10 sine 600 vol 0.01
        fname = '600hz_0.03_10s.wav'
        proc = subprocess.Popen(['aplay', fname, '-d', '5'])
        time.sleep(3)
        spl_value = periph_common.get_wbmqtt().get_average_value(periph_common.serial_device.device_id, 'Sound Level', interval=1)
        print ("SPL VALUE: %s" % spl_value)

        if spl_value is not None:
            self.__class__.last_spl_600hz = float(spl_value)
        else:
            self.__class__.last_spl_600hz = spl_value

        proc.communicate()
        proc.wait()
        self.assertIsNotNone(spl_value)
        self.assertGreaterEqual(float(spl_value), self.SOUND_LEVEL_MIN)
        self.assertLessEqual(float(spl_value), self.SOUND_LEVEL_MAX)


class TestEEPROMPersistence(unittest.TestCase):
    def _get_uptime_counter(self):
        # use AM2320 reads counter as uptime
        return int(periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'AM2320 reads'))

    def test_persistence(self):
        # Serial shouldn't change after power cycle
        serial = periph_common.get_wbmqtt().get_last_or_next_value(periph_common.serial_device.device_id, 'Serial')

        slow_rc_control = 'SPL_RC'

        spl_slow_rc_cur = periph_common.get_wbmqtt().get_last_or_next_value(periph_common.serial_device.device_id, slow_rc_control)
        spl_slow_rc_cur = int(spl_slow_rc_cur)
        if spl_slow_rc_cur % 2 == 0:
            spl_slow_rc = spl_slow_rc_cur + 10
        else:
            spl_slow_rc = spl_slow_rc_cur - 10

        periph_common.get_wbmqtt().send_value(periph_common.serial_device.device_id, slow_rc_control, spl_slow_rc)

        time.sleep(1200E-3) # at least 1 second to save settings to EEPROM

        uptime_before = self._get_uptime_counter()

        periph_common.serial_device.stop_driver()
        periph_common.serial_device.power_off()
        time.sleep(500E-3)
        periph_common.serial_device.power_on()
        periph_common.serial_device.start_driver()

        uptime_after = self._get_uptime_counter()
        self.assertLess(uptime_after, uptime_before, "device wasn't powered off!")

        self.assertEqual(
            periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'Serial'),
            serial)

        self.assertIsNone(periph_common.get_wbmqtt().get_last_error(periph_common.serial_device.device_id, 'Serial'))

        self.assertEqual(
            int(periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, slow_rc_control)),
            spl_slow_rc)


class TestIlluminance(unittest.TestCase):
    LIGHT_SWITCH = ('wb-gpio', 'A3_OUT')
    MAX_AMBIENT = 50
    ILLUMINATED_DIFF = 4600
    ILLUMINATED_DIFF_ERR = 0.12
    # @classmethod
    # def setUpClass(cls):
    #     periph_common.get_wbmqtt().watch_channel(cls.LIGHT_SWITCH[0], cls.LIGHT_SWITCH[1])

    @classmethod
    def _switch_light(self, on):
        periph_common.get_wbmqtt().send_value(self.LIGHT_SWITCH[0], self.LIGHT_SWITCH[1], '1' if on else '0')

    def _get_lux(self):
        return float(periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'Illuminance'))

    def _get_lux_stable(self):
        return periph_common.get_wbmqtt().get_stable_value(periph_common.serial_device.device_id, 'Illuminance', timeout=10, jitter=10)

    @classmethod
    def tearDownClass(cls):
        cls._switch_light(False)

    def test_ambient(self):
        self._switch_light(False)
        time.sleep(2000E-3)
        lux = self._get_lux()
        print "Ambient illuminance: %s lx" % lux
        self.assertLess(lux, self.MAX_AMBIENT)

    def test_illuminated(self):
        ambient_lux = self._get_lux_stable()
        self._switch_light(True)
        time.sleep(2000E-3)
        lux = self._get_lux_stable() - ambient_lux
        print "Illuminance difference: %s lx" %  lux

        self.__class__.last_lux_diff = lux

        self.assertAlmostEqual(lux, self.ILLUMINATED_DIFF , delta = self.ILLUMINATED_DIFF * self.ILLUMINATED_DIFF_ERR)

class TestBuzzer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        periph_common.serial_device.serial_driver.ensure_running()

    def tearDown(self):
        periph_common.get_wbmqtt().send_value(periph_common.serial_device.device_id, 'Buzzer', '0')

    def test_buzzer_on(self):
        periph_common.get_wbmqtt().send_value(periph_common.serial_device.device_id, 'Buzzer', '1')
        time.sleep(1100E-3)
        spl_value = periph_common.get_wbmqtt().get_average_value(periph_common.serial_device.device_id, 'Sound Level', interval=0.5)

        if spl_value is not None:
            self.__class__.last_spl_on = float(spl_value)
        else:
            self.__class__.last_spl_on = spl_value

        self.assertIsNotNone(spl_value)
        self.assertGreater(float(spl_value), 75)



class TestCO2(unittest.TestCase):
    def test_co2(self):
        value = periph_common.get_wbmqtt().get_next_value(periph_common.serial_device.device_id, 'CO2')
        print "CO2: %s ppm" % value
        self.assertIsNotNone(value)
        self.assertGreaterEqual(float(value), 380)
        self.assertLessEqual(float(value), 2000)


class MSTesterBase(PeriphTesterBase):
    SUPPORT_UART_SETTINGS = True
    POWER_FET = ('wb-gpio','EXT1_HS7')
    def append_to_log_row(self):
        values_row = ["", ] * 5
        for test in self.mapping.iterkeys():
            if issubclass(test, TestTH):
                values_row[0] = test.last_humidity
                values_row[1] = test.reference_humidity

            if issubclass(test, TestIlluminance):
                values_row[2] = test.last_lux_diff

            if issubclass(test, TestSPL):
                values_row[3] = test.last_spl_600hz

            if issubclass(test, TestBuzzer):
                values_row[4] = test.last_spl_on

        return values_row

