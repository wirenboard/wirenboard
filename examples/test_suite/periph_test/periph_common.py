import unittest
from collections import OrderedDict
import sys
import os
import datetime
import hashlib
import time
import subprocess
sys.path.insert(0, "../hw_test_common")

from arg_printing_parser import ArgPrintingParser
import argparse

import tempfile
import json

    
from wb_common import leds
from wb_common import beeper

import labels

from wb_common.wbmqtt import WBMQTT
wbmqtt = WBMQTT()

def get_wbmqtt():
    return wbmqtt

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
        if self.serial_driver_proc:
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
    def __init__(self, config_template, port='/dev/ttyAPP4', slave_id = 1,
                 device_id=None, stop_bits=2, baud_rate=9600, parity='N',
                 power_fet=('wb-gpio','EXT1_HS7'),
                 support_uart_settings=False):

        config = json.load(open(config_template))
        self.power_fet = power_fet 
        self.support_uart_settings = support_uart_settings


        assert 1 <= slave_id <= 247

        self.port = port
        self.slave_id = slave_id
        self.stop_bits = stop_bits
        self.baud_rate = baud_rate
        self.parity = parity

        config[u'ports'][0]['path'] = self.port
        assert self.stop_bits in (1, 2)
        config[u'ports'][0]['stop_bits'] = self.stop_bits
        config[u'ports'][0]['baud_rate'] = self.baud_rate
        assert self.parity in ('N', 'E', 'O')

        config[u'ports'][0]['parity'] = self.parity

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
        return int(wbmqtt.get_last_or_next_value(self.device_id, "Serial"))

    def get_fw_ver(self):
        chars = []
        for i in xrange(9):
            c = wbmqtt.get_last_or_next_value(self.device_id, "fw_ver_%d" % i)
            chars.append(c)
        return "".join(chars).strip()

    def set_serial(self, serial):
        wbmqtt.send_value(self.device_id, "Serial", serial)


    def _get_modbus_client_cmd_prefix(self, cmd_baud_rate, cmd_stop_bits, cmd_parity):
        cmd_str_prefix = "modbus_client -m rtu -o100 -pnone -s%d -b%d %s " % (
                        cmd_stop_bits, cmd_baud_rate,
                        self.port)

        return cmd_str_prefix

    def _set_modbus_address(self, cmd_baud_rate, cmd_stop_bits, cmd_parity):
        cmd_str_prefix = self._get_modbus_client_cmd_prefix(cmd_baud_rate, 
                                                            cmd_stop_bits, cmd_parity)

        print cmd_str_prefix
        # trying to set address
        subprocess.call(cmd_str_prefix + "-t0x06 -a0 -r0x80 %d" % (self.slave_id), shell=True)

    def _set_settings_w_uart(self, cmd_baud_rate, cmd_stop_bits, cmd_parity):
        """ returns True if ok"""

        cmd_str_prefix = self._get_modbus_client_cmd_prefix(cmd_baud_rate, 
                                                            cmd_stop_bits, cmd_parity)

        print cmd_str_prefix

        # trying to set address
        self._set_modbus_address(cmd_baud_rate, cmd_stop_bits, cmd_parity)

        # trying to set proper uart settings (baud rate, parity, stop bits)
        ret = subprocess.call(cmd_str_prefix + "-t0x10 -a%d -r110 %d %d %d" % (self.slave_id, self.baud_rate / 100,
            {'N': 0, 'O' : 1, 'E': 2}[self.parity],
            self.stop_bits), shell=True)

        return (ret == 0)

    def set_settings(self):
        self.serial_driver.kill_existing()
        if not self.support_uart_settings:
            self._set_modbus_address(self.baud_rate, self.stop_bits, self.parity)
        else:
            for cmd_parity in ('none', 'even', 'odd'):
                for cmd_stop_bits in (2, 1):
                    for cmd_baud_rate in (9600, 19200):
                        if self._set_settings_w_uart(cmd_baud_rate, cmd_stop_bits, cmd_parity):
                            return

        

                    time.sleep(0.1)

    def power_off(self):
        wbmqtt.send_value(self.power_fet[0], self.power_fet[1], '0')

    def power_on(self):
        wbmqtt.send_value(self.power_fet[0], self.power_fet[1], '1')



class ModbusDeviceTestLog(object):
    SN_COLUMN = 3
    def __init__(self):
        self.log = None

    def init(self):
        if self.log is None:
            from gsheets import GSheetsLog
            self.log = GSheetsLog('1gN56RBi__Y7n44XVklc1vjl_FRCkizIJeHsrXZRItr0',
                             '../hw_test_common/Commissioning-30b68b322b7c.json')
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




class PeriphTesterBase(object):
    SUPPORT_UART_SETTINGS = False
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
        self.parser = ArgPrintingParser(description='MSW Testing Tool', add_help=True, formatter_class=argparse.ArgumentDefaultsHelpFormatter)

        self.parser.add_argument('-i', '--ignore-tests', dest='ignore_tests', type=str,
                         help='List of tests to ignore (but still perform)', default='')

        self.parser.add_argument('-s', '--skip-tests', dest='skip_tests', type=str,
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
        self.parser.print_args(self.args)

    def add_testing_params(self):
        self.parser.add_argument('-a', '--address', dest='modbus_address', type=int,
                         help='Modbus address (slave id) to assign', default=1)

        self.parser.add_argument('-b', '--serial-base', dest='serial_base', type=int,
                                 help='S/N base', default=1100000)

        self.parser.add_argument('-c', '--comments', dest='comments', type=str,
                                 help='Comments', default='')

        self.parser.add_argument('-r', '--hw-rev', dest='hw_rev', type=str,
                                 help='HW revision', default='')

        self.parser.add_argument('-m', '--model', dest='device_model', type=str,
                                 help='Device model', default='??')

        self.parser.add_argument('-t', '--tester', dest='tester_name', type=str,
                                 help='Who operates the testing stand', default='??')

        self.parser.add_argument('-p', '--batch', dest='batch_no', type=str,
                                 help='Batch #', default='??')

        self.parser.add_argument('--stop-bits', dest='stop_bits', type=int,
                                 help='Stop bits', default=2,
                                 choices=(1,2))

        self.parser.add_argument('--baud-rate', dest='baud_rate', type=int,
                                 help='Baud rate', default=9600,
                                 choices=(9600, 19200, 38400, 57600, 115200))

        self.parser.add_argument('--parity', dest='parity',
                                 help='Parity', default='N',
                                 choices=('N', 'E', 'O'))


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

    def append_to_log_row(self):
        return []

    def main(self):
        global serial_device

        self.init_argparser()
        self.add_testing_params()

        self.parse_args()
        self.print_args()
        self.parse_skipped_tests()


        serial_device = SerialDeviceHandler(self.CONFIG_FNAME, device_id = self.MQTT_DEVICE_ID,
                                            slave_id=self.args.modbus_address,
                                            stop_bits=self.args.stop_bits,
                                            baud_rate=self.args.baud_rate,
                                            parity=self.args.parity,
                                            power_fet=self.POWER_FET,
                                            support_uart_settings=self.SUPPORT_UART_SETTINGS
                                            )

        serial_device.stop_driver()

        wbmqtt.clear_device(serial_device.device_id)
        wbmqtt.watch_device(serial_device.device_id)


        serial_device.power_on()
        time.sleep(50E-3)
        serial_device.set_settings()

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

        serial_device.stop_driver()

        has_real_errors, overall_status, results_row = self.process_results(result)

        self.indicate_status(sn, overall_status, has_real_errors)


        test_log.init()
        test_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        row = [overall_status, self.args.device_model, sn, test_date, self.args.modbus_address, self.args.hw_rev, '', fw_ver, self.args.comments,  self.args.tester_name, self.args.batch_no,'',''] + results_row




        row += self.append_to_log_row()


        # label is printed if
        # 1) S/N was assigned for the first time, regardless of Q.C. status
        # 2) Q.C. is passed, in which case a set of TWO labels is printed
        #   each with "OK" status printed on it

        if sn_assigned or not has_real_errors:
            label_fname = '/tmp/label.png'
            label_caption = 'A:%d SN:%d' % (self.args.modbus_address, sn)

            if has_real_errors:
                copies = 1
            else:
                label_caption += ' OK'
                copies = 2


            labels.make_barcode_w_caption(label_fname,
                barcode_contents=str(sn),
                caption_contents=label_caption)
            labels.print_label(label_fname, copies=copies)


            print "The label has been printed"

        test_log.send_data(sn_assigned, row)

        print "Done!"

        beep = beeper.Beeper(3)
        beep.setup()

        # if has_real_errors:
        #     beep.beep(0.07, 10)
        # else:
        #     beep.beep(0.5, 3)


