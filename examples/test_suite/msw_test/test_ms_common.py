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
wbmqtt = None

def suite(mapping):
    suite = unittest.TestSuite()

    for test_class in mapping.iterkeys():
        suite.addTest(unittest.makeSuite(test_class))

    return suite

serial_device = None

def parse_comma_separated_set(list_str):
    return set(int(x) for x in list_str.strip().split(',')) if list_str else set()


class SerialDriverHandler(object):
    def __init__(self, config_fname):
        self.config_fname = config_fname
        self.serial_driver_proc = None

    def start(self):
        self.kill_existing()
        self.serial_driver_proc = subprocess.Popen(['wb-mqtt-serial', '-c', self.config_fname])
        time.sleep(2)

    def stop(self):
        self.serial_driver_proc.kill()
        self.serial_driver_proc.communicate()

    def is_running(self):
        return (self.serial_driver_proc is not None) and (self.serial_driver_proc.poll() is None)

    def ensure_running(self):
        if not self.is_running():
            self.start()

    def kill_existing(self):
        subprocess.call("killall -9 wb-mqtt-serial", shell=True)



class SerialDeviceHandler(object):
    power_fet = ('wb-gpio', 'EXT1_HS7')

    def __init__(self, config_template, port='/dev/ttyAPP4', slave_id = 1, device_id=None):
        config = json.load(open(config_template))

        assert 1 <= slave_id <= 247

        self.port = port
        self.slave_id = slave_id

        config[u'ports'][0]['path'] = self.port
        assert len(config[u'ports'][0]['devices']) == 1
        config[u'ports'][0]['devices'][0]['slave_id'] = self.slave_id
        if device_id:
            config[u'ports'][0]['devices'][0]['id'] = device_id

        self.device_id = device_id

        self.tmpfile = '/tmp/%s.conf' % self.device_id
        open(self.tmpfile,'wt').write(json.dumps(config))

        self.serial_driver = SerialDriverHandler(self.tmpfile)


    def start_driver(self):
        self.serial_driver.start()

    def stop_driver(self):
        self.serial_driver.stop()

    def get_serial(self):
        return int(wbmqtt.get_next_value(self.device_id, "Serial"))

    def get_fw_ver(self):
        chars = []
        for i in xrange(9):
            c = wbmqtt.get_next_value(self.device_id, "fw_ver_%d" % i)
            chars.append(c)
        return "".join(chars).strip()

    def set_serial(self, serial):
        wbmqtt.send_value(self.device_id, "Serial", serial)


    def broadcast_set_address(self):
        self.serial_driver.kill_existing()

        subprocess.call("modbus_client -m rtu -pnone -s2 %s -a0 -t0x06 -r0x80 %d" % (self.port, self.slave_id), shell=True)

    def power_off(self):
        wbmqtt.send_value(self.power_fet[0], self.power_fet[1], '0')

    def power_on(self):
        wbmqtt.send_value(self.power_fet[0], self.power_fet[1], '1')


class AM2320ReferenceMixin(object):
    @classmethod
    def _set_reference_humidity(cls):
        cls.reference_humidity = float(wbmqtt.get_last_or_next_value('am2320', 'humidity'))
    @classmethod
    def _set_reference_temperature(cls):
        cls.reference_temperature = float(wbmqtt.get_last_or_next_value('am2320', 'temperature'))


class TestTH(unittest.TestCase, AM2320ReferenceMixin):
    @classmethod
    def setUpClass(cls):
        cls._set_reference_temperature()
        cls._set_reference_humidity()

    def test_humidity(self):
        value = wbmqtt.get_next_value(serial_device.device_id, 'Humidity')
        print "Humidity: %s" % value

        if value is None:
            self.__class__.last_humidity = None
        else:
            self.__class__.last_humidity = float(value)

        self.assertIsNotNone(value)
        self.assertAlmostEqual(float(value), self.reference_humidity, delta = 7)

    def test_temperature(self):
        value = wbmqtt.get_next_value(serial_device.device_id, 'Temperature')
        print "Temperature: %s" % value
        self.assertIsNotNone(value)

        self.assertAlmostEqual(float(value), self.reference_temperature, delta = 1.5)

    def test_error_count(self):
        while True:
            am2320_reads = int(wbmqtt.get_next_value(serial_device.device_id, 'AM2320 reads'))
            if am2320_reads < 5:
                continue

            am2320_errors = int(wbmqtt.get_last_or_next_value(serial_device.device_id, 'AM2320 errors'))
            self.assertLess(am2320_errors, am2320_reads / 2 + 1)

            return

class TestHStrict(unittest.TestCase, AM2320ReferenceMixin):
    @classmethod
    def setUpClass(cls):
        cls._set_reference_humidity()

    def test_humidity_strict(self):
        value = wbmqtt.get_next_value(serial_device.device_id, 'Humidity')
        print "Humidity: %s" % value

        self.assertIsNotNone(value)
        self.assertAlmostEqual(float(value), self.reference_humidity, delta = 3)

class Test1Wire(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference_temperature = float(wbmqtt.get_last_or_next_value('am2320', 'temperature'))

    def _test_1wire_temp(self, channel):
        assert 1 <= channel <= 2
        value = wbmqtt.get_next_value(serial_device.device_id, 'External Sensor %d' % channel, timeout=2)
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
        serial_device.serial_driver.ensure_running()

    def test_ambient(self):
        time.sleep(200E-3)
        spl_value = wbmqtt.get_average_value(serial_device.device_id, 'Sound Level', interval=2)
        print ("Ambient value: %s" % spl_value)
        self.assertIsNotNone(spl_value)
        self.assertLess(float(spl_value), self.AMBIENT_MAX)

    def test_s600hz(self):
        #sox -n -r 44100 600hz_0.01_10s.wav  synth 10 sine 600 vol 0.01
        fname = '600hz_0.03_10s.wav'
        proc = subprocess.Popen(['aplay', fname, '-d', '5'])
        time.sleep(3)
        spl_value = wbmqtt.get_average_value(serial_device.device_id, 'Sound Level', interval=1)
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
        return int(wbmqtt.get_next_value(serial_device.device_id, 'AM2320 reads'))

    def test_persistence(self):
        # Serial shouldn't change after power cycle
        serial = wbmqtt.get_last_or_next_value(serial_device.device_id, 'Serial')

        slow_rc_control = 'SPL_RC'

        spl_slow_rc_cur = wbmqtt.get_last_or_next_value(serial_device.device_id, slow_rc_control)
        spl_slow_rc_cur = int(spl_slow_rc_cur)
        if spl_slow_rc_cur % 2 == 0:
            spl_slow_rc = spl_slow_rc_cur + 10
        else:
            spl_slow_rc = spl_slow_rc_cur - 10

        wbmqtt.send_value(serial_device.device_id, slow_rc_control, spl_slow_rc)

        time.sleep(500E-3)

        uptime_before = self._get_uptime_counter()

        serial_device.stop_driver()
        serial_device.power_off()
        time.sleep(500E-3)
        serial_device.power_on()
        serial_device.start_driver()

        uptime_after = self._get_uptime_counter()
        self.assertLess(uptime_after, uptime_before, "device wasn't powered off!")

        self.assertEqual(
            wbmqtt.get_next_value(serial_device.device_id, 'Serial'),
            serial)

        self.assertIsNone(wbmqtt.get_last_error(serial_device.device_id, 'Serial'))

        self.assertEqual(
            int(wbmqtt.get_next_value(serial_device.device_id, slow_rc_control)),
            spl_slow_rc)


class TestIlluminance(unittest.TestCase):
    LIGHT_SWITCH = ('wb-gpio', 'A3_OUT')
    MAX_AMBIENT = 50
    ILLUMINATED_DIFF = 4600
    ILLUMINATED_DIFF_ERR = 0.12
    # @classmethod
    # def setUpClass(cls):
    #     wbmqtt.watch_channel(cls.LIGHT_SWITCH[0], cls.LIGHT_SWITCH[1])

    @classmethod
    def _switch_light(self, on):
        wbmqtt.send_value(self.LIGHT_SWITCH[0], self.LIGHT_SWITCH[1], '1' if on else '0')

    def _get_lux(self):
        return float(wbmqtt.get_next_value(serial_device.device_id, 'Illuminance'))

    def _get_lux_stable(self):
        return wbmqtt.get_stable_value(serial_device.device_id, 'Illuminance', timeout=10, jitter=10)

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
        serial_device.serial_driver.ensure_running()

    def tearDown(self):
        wbmqtt.send_value(serial_device.device_id, 'Buzzer', '0')

    def test_buzzer_on(self):
        wbmqtt.send_value(serial_device.device_id, 'Buzzer', '1')
        time.sleep(1100E-3)
        spl_value = wbmqtt.get_average_value(serial_device.device_id, 'Sound Level', interval=0.5)

        if spl_value is not None:
            self.__class__.last_spl_on = float(spl_value)
        else:
            self.__class__.last_spl_on = spl_value

        self.assertIsNotNone(spl_value)
        self.assertGreater(float(spl_value), 75)



class TestCO2(unittest.TestCase):
    def test_co2(self):
        value = wbmqtt.get_next_value(serial_device.device_id, 'CO2')
        print "CO2: %s ppm" % value
        self.assertIsNotNone(value)
        self.assertGreaterEqual(float(value), 380)
        self.assertLessEqual(float(value), 2000)


class ModbusDeviceTestLog(object):
    SN_COLUMN = 3
    def __init__(self):
        self.log = None

    def init(self):
        if self.log is None:
            from gsheets import GSheetsLog
            self.log = GSheetsLog('1gN56RBi__Y7n44XVklc1vjl_FRCkizIJeHsrXZRItr0',
                             '../Commissioning-30b68b322b7c.json')
    def get_all_serials(self):
        range_spec = "%s:%s" % (self.log.get_addr_int(1, self.SN_COLUMN),
                        self.log.get_addr_int(10000, self.SN_COLUMN))

        return [row[0] for row in self.log.get_range_contents(range_spec) if row]

    @staticmethod
    def _count_trailing_zeros(serial_base):
        serial_base = str(serial_base)
        for i in xrange(len(serial_base)):
            if serial_base[-(i+1)] != '0':
                return i


    def get_next_serial(self, serial_base):
        serials = self.get_all_serials()
        serials = [int(sn) for sn in serials if sn.isdigit()]

        max_allowed_sn = serial_base + 10**(self._count_trailing_zeros(serial_base)) - 1

        this_base_serials = [sn for sn in serials if (serial_base <= sn <= max_allowed_sn)]

        if not this_base_serials:
            return serial_base
        else:
            max_sn_present = max(this_base_serials)

            if max_sn_present == max_allowed_sn:
                raise RuntimeError("cannot find free serial within the specified base")

            return max_sn_present + 1

    def send_data(self, sn_assigned, row):
        print "sending data to google..."
        if sn_assigned:
            self.log.append_row(row)
        else:
            print "update row"


            self.log.update_row_by_primary_key(self.SN_COLUMN, row)




class MSTesterBase(object):
    def __init__(self):
        self.init_mapping()
        self._parser_arguments = {}

    def process_results(self, result):
        # process results
        results_row = ['--', ] * (max(self.mapping.values()))

        for test_class, test_index in self.mapping.iteritems():
            if test_index in self.ignore_tests:
                results_row[test_index-1] = 'OK/NP'
            else:
                results_row[test_index-1] = 'OK'

        has_real_errors = False
        for test, err_msg in (result.errors + result.failures):
            test_index = self.mapping[test.__class__]
            if test_index in self.ignore_tests:
                results_row[test_index-1] = 'FAIL/NP'
            else:
                results_row[test_index-1] = 'FAIL'
                has_real_errors = True

        overall_status = 'OK' if (not has_real_errors) else 'FAIL'

        return has_real_errors, overall_status, results_row

    def init_argparser(self):
        self.parser = argparse.ArgumentParser(description='MSW Testing Tool', add_help=True, formatter_class=argparse.ArgumentDefaultsHelpFormatter)

        self._add_parser_argument('-i', '--ignore-tests', dest='ignore_tests', type=str,
                         help='List of tests to ignore (but still perform)', default='')

        self._add_parser_argument('-s', '--skip-tests', dest='skip_tests', type=str,
                         help='List of tests to skip', default='')

    def parse_skipped_tests(self):
        skip_tests = parse_comma_separated_set(self.args.skip_tests)
        if skip_tests:
            print "Will skip tests: " + ",".join(str(x) for x in skip_tests)

        self.ignore_tests = parse_comma_separated_set(self.args.ignore_tests)
        if self.ignore_tests:
            print "Will ignore tests: " + ",".join(str(x) for x in self.ignore_tests)


        # delete tests we would like to skip
        if skip_tests:
            filtered_mapping = OrderedDict()
            for test_class, test_index in self.mapping.iteritems():
                if test_index in skip_tests:
                    print "Will skip %s test" % test_class.__name__
                else:
                    filtered_mapping[test_class] = test_index
            self.mapping = filtered_mapping
    def parse_args(self):
        self.args = self.parser.parse_args()

    def print_args(self):
        print "======== Command-line parameters: =========="
        for k, v in self.args._get_kwargs():
            if k in self._parser_arguments:
                print "%s: %s" % (self._parser_arguments[k], v)
        print "============================================"


    def _add_parser_argument(self, *args, **kwargs):
        dest = kwargs.get('dest')
        self._parser_arguments[dest] = kwargs.get('help')
        return self.parser.add_argument(*args, **kwargs)

    def add_testing_params(self):
        self._add_parser_argument('-a', '--address', dest='modbus_address', type=int,
                         help='Modbus address (slave id) to assign', default=1)

        self._add_parser_argument('-b', '--serial-base', dest='serial_base', type=int,
                                 help='S/N base', default=1100000)

        self._add_parser_argument('-c', '--comments', dest='comments', type=str,
                                 help='Comments', default='')

        self._add_parser_argument('-r', '--hw-rev', dest='hw_rev', type=str,
                                 help='HW revision', default='')

        self._add_parser_argument('-m', '--model', dest='device_model', type=str,
                                 help='Device model', default='??')

        self._add_parser_argument('-t', '--tester', dest='tester_name', type=str,
                                 help='Who operates the testing stand', default='??')

        self._add_parser_argument('-p', '--batch', dest='batch_no', type=str,
                                 help='Batch #', default='??')


    def indicate_status(self, sn, overall_status, has_real_errors):

        print "====================================="
        print "S/N:       %s                        " % sn
        print "Overall status:    %s    " % overall_status
        print "====================================="


        if not has_real_errors:
            leds.set_brightness('red', 0)
            leds.blink_fast('green')
        else:
            leds.blink_fast('red')
            leds.set_brightness('green', 0)


    def main(self):
        global serial_device

        self.init_argparser()
        self.add_testing_params()

        self.parse_args()
        self.print_args()
        self.parse_skipped_tests()


        serial_device = SerialDeviceHandler(self.CONFIG_FNAME,device_id = self.MQTT_DEVICE_ID, slave_id = self.args.modbus_address)
        wbmqtt.watch_device(        serial_device.device_id)


        serial_device.power_on()
        time.sleep(50E-3)
        serial_device.broadcast_set_address()

        serial_device.start_driver()


        test_log = ModbusDeviceTestLog()

        sn = serial_device.get_serial()
        print "Got serial: ", sn
        sn_assigned = False

        fw_ver = serial_device.get_fw_ver()
        print "Got fw version: ", fw_ver

        if sn == 0:
            test_log.init()
            sn = test_log.get_next_serial(self.args.serial_base)
            print "Will use S/N: ", sn
            serial_device.set_serial(sn)
            sn_assigned = True


        result = unittest.TextTestRunner(verbosity=2).run(suite(self.mapping))

        has_real_errors, overall_status, results_row = self.process_results(result)

        self.indicate_status(sn, overall_status, has_real_errors)


        test_log.init()
        test_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        row = [overall_status, self.args.device_model, sn, test_date, self.args.modbus_address, self.args.hw_rev, '', fw_ver, self.args.comments,  self.args.tester_name, self.args.batch_no,'',''] + results_row

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

        row += values_row
        

        test_log.send_data(sn_assigned, row)

        print "Done!"

        beep = beeper.Beeper(3)
        beep.setup()

        # if has_real_errors:
        #     beep.beep(0.07, 10)
        # else:
        #     beep.beep(0.5, 3)

        serial_device.stop_driver()

