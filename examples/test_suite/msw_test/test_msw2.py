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

from test_ms_common import TestSPL, TestTH, TestEEPROMPersistence, parse_comma_separated_set

def suite(mapping):
    suite = unittest.TestSuite()

    for test_class in mapping.iterkeys():
        suite.addTest(unittest.makeSuite(test_class))

    return suite

wbmqtt = None

serial_device = None



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

class Tester(object):
    def __init__(self):
        self.mapping = OrderedDict([
                (TestSPL, 2),
                (TestIlluminance, 3),
                (TestTH, 4),
                (TestCO2, 5),
                (TestBuzzer, 6),
                (TestEEPROMPersistence, 1),
        ])

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
            print "Will ignore tests: " + ",".join(str(x) for x in ignore_tests)


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

        mqtt_device_id = 'wbmsw2-test'


        serial_device = SerialDeviceHandler("wbmsw2.conf",device_id = mqtt_device_id, slave_id = self.args.modbus_address)


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

        test_log.send_data(sn_assigned, row)

        print "Done!"

        beep = beeper.Beeper(3)
        beep.setup()

        # if has_real_errors:
        #     beep.beep(0.07, 10)
        # else:
        #     beep.beep(0.5, 3)

        serial_device.stop_driver()


if __name__ == '__main__':
    while 1:
        try:
            wbmqtt = WBMQTT()
            wbmqtt.watch_device('am2320')

            Tester().main()
        finally:
            wbmqtt.close()

        while 1:
            e = raw_input("press Enter to continue or Control+C to exit")
            if e == '':
                break

        print "\n" * 5



