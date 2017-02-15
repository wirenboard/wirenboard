import unittest
from collections import OrderedDict
import sys
import os
import datetime
import hashlib
import time
import subprocess
from wb_common.wbmqtt import WBMQTT
sys.path.insert(0, "../hw_test_common")

from periph_common import PeriphTesterBase
import periph_common
import discrete_test


class TestMR14Outputs(discrete_test.TestDiscreteBase):
    NUM_CHANNELS = 14
    OUT_DEVICE_ID = 'mr14'
    OUT_CONTROL_ID_FMT = 'K%d'
    IN_DEVICE_ID = 'wb-gpio'
    IN_CONTROL_ID_FMT = 'EXT2_K%d'

for i in xrange(1, TestMR14Outputs.NUM_CHANNELS + 1):
    setattr(TestMR14Outputs, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i, check_turn_back=True))(i))



class TestVoltage(unittest.TestCase):
    def test_voltage(self):
        reference_voltage = float(wbmqtt.get_last_or_next_value('wb-adc', 'Vin'))
        value = wbmqtt.get_next_value(periph_common.serial_device.device_id, 'Supply voltage')
        print "Voltage: %s v" % value

        self.assertIsNotNone(value)

        self.assertAlmostEqual(float(value), reference_voltage, delta=1.5)


class TestEEPROMPersistence(unittest.TestCase):
    # def _get_uptime_counter(self):
    #     # use AM2320 reads counter as uptime
    #     return int(wbmqtt.get_next_value(periph_common.serial_device.device_id, 'AM2320 reads'))

    SAVE_STATE_CTRL = 'SAVE_RELAY_STATE'

    def _single_power_cycle(self, save_relay_state_val):
        """ Sets "relay state", performs write cycle and checks that the value is successfully restored afterward"""

        wbmqtt.send_value(periph_common.serial_device.device_id, self.SAVE_STATE_CTRL, str(int(save_relay_state_val)))

        serial = wbmqtt.get_last_or_next_value(periph_common.serial_device.device_id, 'Serial')

        # # Serial is not update in EEPROM, so it expected to be restored after the power cycle
        # wbmqtt.send_value(periph_common.serial_device.device_id, 'Serial', str(int(serial) + 1))


        time.sleep(1200E-3) # at least 1 second to save settings to EEPROM

        periph_common.serial_device.stop_driver()
        periph_common.serial_device.power_off()
        time.sleep(200E-3)
        wbmqtt.clear_value(periph_common.serial_device.device_id, 'Serial')
        wbmqtt.clear_value(periph_common.serial_device.device_id, self.SAVE_STATE_CTRL)

        periph_common.serial_device.power_on()
        periph_common.serial_device.start_driver()

        self.assertEqual(
            wbmqtt.get_last_or_next_value(periph_common.serial_device.device_id, 'Serial'),
            serial)
        self.assertIsNone(wbmqtt.get_last_error(periph_common.serial_device.device_id, 'Serial'))

        self.assertEqual(
            int(wbmqtt.get_last_or_next_value(periph_common.serial_device.device_id, self.SAVE_STATE_CTRL)),
            save_relay_state_val)



    def test_persistence(self):
        save_state_cur = wbmqtt.get_last_or_next_value(periph_common.serial_device.device_id, self.SAVE_STATE_CTRL)
        save_state_cur = int(save_state_cur)

        if save_state_cur == 1:
            print "Set %s to 0 first" % self.SAVE_STATE_CTRL
            self._single_power_cycle(0)

        self._single_power_cycle(1)

        #restore "save relay state"
        self._single_power_cycle(0)

class Tester(PeriphTesterBase):
    MQTT_DEVICE_ID = 'mr14'
    CONFIG_FNAME = "mr14ni.conf"
    POWER_FET=('wb-gpio', 'MOD1_OUT1')

    def init_mapping(self):
        self.mapping = OrderedDict([
            (TestMR14Outputs, 3),
            (TestVoltage, 2),
            (TestEEPROMPersistence, 1),
        ])



if __name__ == '__main__':
    while 1:
        try:
            periph_common.wbmqtt = WBMQTT()
            wbmqtt = periph_common.wbmqtt
            discrete_test.wbmqtt = wbmqtt

            # wbmqtt.watch_device('mr14')
            # wbmqtt.watch_device('wb-gpio')
            Tester().main()
        finally:
            wbmqtt.close()

        while 1:
            e = raw_input("press Enter to continue or Control+C to exit")
            if e == '':
                break

        print "\n" * 5
