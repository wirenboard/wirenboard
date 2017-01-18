import unittest
from collections import OrderedDict
import sys
from select import select
import subprocess
import argparse

sys.path.insert(0, "../hw_test_common")

import time
from wb_common import leds
from wb_common import beeper
from wb_common.wbmqtt import WBMQTT

import discrete_test

wbmqtt = None

def raw_input_timeout(prompt, timeout=None):
    sys.stdout.write(prompt)
    sys.stdout.flush()
    rlist, _, _ = select([sys.stdin], [], [], timeout)
    if rlist:
        s = sys.stdin.readline()[:-1]
        return s
    else:
        return None


    # def _test_single_channel_off(self, channel):
    #     self._set_out_state(channel, False)



class TestWBIO(discrete_test.TestDiscreteBase):
    NUM_CHANNELS = 8
    OUT_DEVICE_ID = 'wb-gpio'
    OUT_CONTROL_ID_FMT = 'EXT1_K%d'
    IN_DEVICE_ID = 'wb-gpio'
    IN_CONTROL_ID_FMT = 'EXT2_DR%d'

    @classmethod
    def _prepare(cls):
        subprocess.call("service wb-homa-gpio stop ; for i in `seq 256 400`; do echo $i > /sys/class/gpio/unexport ; done ; modprobe  -r gpio_mcp23s08 ; modprobe  gpio_mcp23s08 && service wb-homa-gpio start", shell=True)

        time.sleep(2)

        leds.set_brightness('green', 0)
        leds.set_brightness('red', 0)
        beep.beep(0.05, 1)


from functools import partial



class TestWBIO16(TestWBIO):
    NUM_CHANNELS = 16

for i in xrange(1, TestWBIO16.NUM_CHANNELS + 1):
    setattr(TestWBIO16, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i, check_turn_back=False))(i))

class TestInputs16(TestWBIO):
    NUM_CHANNELS = 16

for i in xrange(1, TestInputs16.NUM_CHANNELS + 1):
    setattr(TestInputs16, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i, check_turn_back=False))(i))

class TestWBIO8(TestWBIO):
    NUM_CHANNELS = 8

for i in xrange(1, TestWBIO8.NUM_CHANNELS + 1):
    setattr(TestWBIO8, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i))(i))


class TestR1G16(TestWBIO16):
    pass

for i in xrange(1, TestR1G16.NUM_CHANNELS + 1):
    setattr(TestR1G16, 'test_2_toggle_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_multiple_toggle(i, 10))(i))

class TestR1G12(TestWBIO16):
    NUM_CHANNELS = 12
for i in xrange(1, TestR1G12.NUM_CHANNELS + 1):
    setattr(TestR1G12, 'test_2_toggle_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_multiple_toggle(i, 10))(i))


class TestMR14(discrete_test.TestDiscreteBase):
    NUM_CHANNELS = 14
    OUT_DEVICE_ID = 'wb-mr14_12'
    OUT_CONTROL_ID_FMT = 'K%d'
    IN_DEVICE_ID = 'wb-gpio'
    IN_CONTROL_ID_FMT = 'EXT1_DR%d'

for i in xrange(1, TestMR14.NUM_CHANNELS + 1):
    setattr(TestMR14, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i))(i))



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='WBIO Testing Tool', add_help=False)

    parser.add_argument('module', choices  = ['r1g16', 'r1g12', 'wbio8', 'hvd16', 'mr14'],
                     help='Module to test')

    parser.add_argument('-f', dest='failfast', action='store_true',
                     help='Fall after first failed test')

    args = parser.parse_args()



    wbmqtt = WBMQTT()
    discrete_test.wbmqtt = wbmqtt
    time.sleep(1)
    print "==="

    suite = unittest.TestSuite()

    test_classes = {'r1g16' : TestR1G16,
                    'r1g12' : TestR1G12,
                    'hvd16' : TestInputs16,
                    'wbio8' : TestWBIO8,
                    'mr14' : TestMR14 }
    if args.module in test_classes:
        test_class = test_classes[args.module]
    else:
        raise RuntimeError("unknown module to test")

    suite.addTest(unittest.makeSuite(test_class))
    failfast = args.failfast
    beep = beeper.Beeper(3)
    beep.setup()

    # if has_real_errors:
    # else:
    
    while 1:

        result = unittest.TextTestRunner(verbosity=2, failfast=failfast).run(suite)
        if len(result.errors + result.failures) != 0:
            print "Status: FAILED"
            leds.blink_fast('red')
            leds.set_brightness('green', 0)
            beep.beep(0.07, 10)
        else:
            print "Status: OK"
            leds.set_brightness('red', 0)
            leds.blink_fast('green')
            beep.beep(0.5, 3)


        while 1:
            print "Waiting for the hw button (A1_IN)"
            # e = raw_input_timeout("press Enter to continue or Control+C to exit")
            # print "returned: '%s'" % e
            # if e == '':
            #     break

            val = wbmqtt.get_next_value('wb-gpio', 'A1_IN', timeout=60)
            if val=='1':
                break


        print "\n" * 5

