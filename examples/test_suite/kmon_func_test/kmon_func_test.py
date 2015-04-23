import unittest
from collections import OrderedDict
import os


import leds
import gsm
import w1
import adc
import gpio
import rs485
import rs232
import relay
import network
import sht1x_test
import button

from gdocs import GSheetsLog

mapping = OrderedDict([
    ( button.TestProgButton, 9),
    ( rs485.TestRS485      , 6 ),
    ( rs232.TestRS232Front , 7 ),
    ( rs232.TestRS232Back  , 8 ),
    ( gpio.TestGPIO        , 3 ),
    ( adc.TestADC          , 4 ),
    ( w1.TestW1            , 5 ),
    ( network.TestNetwork,   1 ),
    ( sht1x_test.TestSht1x,  2 ),
    ( gsm.TestGSM          , 0 ),
])



def suite():
    suite = unittest.TestSuite()

    for test_class in mapping.iterkeys():
        suite.addTest(unittest.makeSuite(test_class))

    return suite




def get_mac():
   return os.popen('wb-gen-serial').read().strip()


def print_sn(sn):
    print "====================================="
    print "IMEI SN:     %s %s      " % (str(sn)[:3], str(sn)[3:])
    print "====================================="

def test_sound():
    os.system('play  -r 8000 -n -c1 synth sin 3000 trim 0 1')
    os.system('play  -r 8000 -n -c1 synth sin 3000 trim 0 3')



if __name__ == '__main__':
    leds.set_brightness('green', 0)
    leds.set_brightness('red', 0)
    test_sound()

    relay.init()

    gsm.init_gsm()
    imei = gsm.gsm_get_imei()
    print "imei=%s" % imei


    mac = get_mac()

    result = unittest.TextTestRunner(verbosity=2).run(suite())


    results_row = ['--', ]  * (max(mapping.values()) + 1)

    for test_class, test_index in mapping.iteritems():
        results_row[test_index] = 'OK'

    for test, err_msg in (result.errors + result.failures):
        test_index = mapping[test.__class__]
        results_row[test_index] = 'FAIL'


    overall_status = 'OK' if result.wasSuccessful() else 'FAIL'

    log = GSheetsLog('https://docs.google.com/a/contactless.ru/spreadsheets/d/1g6hC75iE88_vwFXX7P2semwyADEWB13KMc0nDmB62LI/edit#gid=0')
    log.update_data(imei, overall_status, [mac,] +  results_row)


    if len(result.errors + result.failures) == 0:
        leds.blink_fast('green')
    else:
        leds.blink_fast('red')

    prefix, sn, crc = log.split_imei(imei)

    print "Done!"
    print "====================================="
    print "Overall status:    %s    " % overall_status
    print "====================================="
    print_sn(sn)
