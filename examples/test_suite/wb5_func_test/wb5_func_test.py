
import unittest
from collections import OrderedDict
import datetime
import subprocess

import argparse

from wb_common import leds, gsm, w1, sysinfo

#~ import gpio
from wb_common import rs485
#~ import relay
from wb_common import network, beeper, rf433, wifi, can

import wb5_adc
import wb5_modrtc

from wb_common.gdocs import GSheetsLog
from wb_common.uid import get_cpuinfo_serial, get_mmc_serial


class WB5TestW1(w1.TestW1):
    NUMBER_REQUIRED = 1


class WB5TestRS485(rs485.TestRS485):
    port_1 = '/dev/ttyAPP1'
    port_2 = '/dev/ttyAPP4'

    @classmethod
    def setUpClass(cls):
        rs485.TestRS485.setUpClass()
        subprocess.call("ifconfig can0 down", shell=True)
        subprocess.call("ifconfig can1 down", shell=True)


class WB5TestRFM69(rf433.TestRFM69):
    SPI_MAJOR = 32765  # -1
    SPI_MINOR = 0
    IRQ_GPIO = 38


gsm_test = gsm.TestGSMMTS
# gsm_test = gsm.TestGSMegafon


def suite(mapping):
    suite = unittest.TestSuite()

    for test_class in mapping.iterkeys():
        suite.addTest(unittest.makeSuite(test_class))

    return suite


def print_sn(sn):
    print "====================================="
    print "Short SN:     %s %s      " % (str(sn)[:4], str(sn)[4:])
    print "====================================="

def parse_comma_separated_set(list_str):
    return set(int(x) for x in list_str.strip().split(',')) if list_str else set()



def get_mac():
    return subprocess.Popen(['wb-gen-serial',  '-m'], stdout=subprocess.PIPE).stdout.read().strip()


def get_serial():
    return subprocess.Popen(['wb-gen-serial', '-s'], stdout=subprocess.PIPE).stdout.read().strip()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='WB5 Function Testing Tool', add_help=False)

    parser.add_argument('-i', '--ignore-tests', dest='ignore_tests', type=str,
                     help='List of tests to ignore (but still perform)', default='')

    parser.add_argument('-s', '--skip-tests', dest='skip_tests', type=str,
                     help='List of tests to skip', default='')

    args = parser.parse_args()



    subprocess.call("killall -9 wb-rules", shell=True)

    beep = beeper.Beeper(3)
    beep.setup()
    beep.test()

    wifi_mac = wifi.get_wlan_mac()
    wb_version = sysinfo.get_wb_version()
    fw_version = sysinfo.get_fw_version()


    mapping = OrderedDict([
        (WB5TestRS485, 6),
        (wifi.TestWifi, 7),
        (WB5TestRFM69, 8),
        (wb5_adc.TestADC55 if (wb_version == '55') else wb5_adc.TestADC52, 4),
        (WB5TestW1, 5),
        (network.TestNetwork, 1),
        (can.TestCAN, 2),
        (gsm_test, 0),
        (gsm.TestGSMRTC, 3),
        (wb5_modrtc.TestModGSMRTC, 9),
    ])


    skip_tests = parse_comma_separated_set(args.skip_tests)
    if skip_tests:
        print "Will skip tests: " + ",".join(str(x) for x in skip_tests)

    ignore_tests = parse_comma_separated_set(args.ignore_tests)
    if ignore_tests:
        print "Will ignore tests: " + ",".join(str(x) for x in ignore_tests)


    try:
        gsm.init_baudrate()
        gsm.init_gsm()
    except RuntimeError:
        print "No GSM modem detected"
        imei = None
    else:
        imei = gsm.gsm_get_imei()
        print "imei=%s" % imei

    cpuinfo_serial = str(get_cpuinfo_serial())
    print "cpuinfo serial: ", cpuinfo_serial

    mmc_serial = str(get_mmc_serial())
    print "mmc serial: ", mmc_serial

    mac = get_mac()

    if imei is not None:
        imei_prefix, imei_sn, imei_crc = gsm.split_imei(imei)
        board_id = imei
    else:
        board_id = cpuinfo_serial + (wifi_mac if wifi_mac else "")
        imei_prefix = "-"


    # New serial generation sequence
    short_sn = get_serial()
    print_sn(short_sn)

    # init CAN extension module on slot2 (hw-specific)
    if wb_version == '55':
        subprocess.call("wb-hwconf-helper init wb55-mod2 wbe-i-can-iso", shell=True)
    else:
        subprocess.call("wb-hwconf-helper init wb5-mod2 wbe-i-can-iso", shell=True)

    results_row = ['--', ] * (max(mapping.values()) + 1)

    # delete tests we would like to skip
    if skip_tests:
        filtered_mapping = OrderedDict()
        for test_class, test_index in mapping.iteritems():
            if test_index in skip_tests:
                print "Will skip %s test" % test_class.__name__
            else:
                filtered_mapping[test_class] = test_index
        mapping = filtered_mapping

    result = unittest.TextTestRunner(verbosity=2).run(suite(mapping))


    for test_class, test_index in mapping.iteritems():
        if test_index in ignore_tests:
            results_row[test_index] = 'OK/NP'
        else:
            results_row[test_index] = 'OK'

    has_real_errors = False
    for test, err_msg in (result.errors + result.failures):
        test_index = mapping[test.__class__]
        if test_index in ignore_tests:
            results_row[test_index] = 'FAIL/NP'
        else:
            results_row[test_index] = 'FAIL'
            has_real_errors = True


    #~ adc_cal = wb4_adc.AdcCalibrate()
    #~ print "r1 constants for R1 and R2 channels:", adc_cal.get_r1_calib(), adc_cal.get_r2_calib()

    #~ results_row += [str(adc_cal.get_r1_calib()), str(adc_cal.get_r2_calib())]

    #~ results_row.append(MEM_TYPE)

    overall_status = 'OK' if (not has_real_errors) else 'FAIL'

    print "====================================="
    print "Overall status:    %s    " % overall_status
    print "====================================="
    print_sn(short_sn)

    if not has_real_errors:
        leds.set_brightness('red', 0)
        leds.blink_fast('green')
    else:
        leds.blink_fast('red')
        leds.set_brightness('green', 0)

    print "sending data to google..."

    log = GSheetsLog('https://docs.google.com/spreadsheets/d/1wKNCMss9ZSyhtr0GFNvRgaGyw2RRPn9weE8w7qjxHiw/edit#gid=0',
                     '../common/Commissioning-30b68b322b7c.json')
    test_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log.update_data(board_id, short_sn, overall_status,
                    [imei, wifi_mac, mac, cpuinfo_serial, mmc_serial] +
                    results_row +
                    [ wb_version, fw_version, test_date]
                    )

    print "Done!"

    if has_real_errors:
        beep.beep(0.07, 10)
    else:
        beep.beep(0.5, 3)
