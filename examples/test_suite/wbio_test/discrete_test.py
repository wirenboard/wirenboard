import unittest
from collections import OrderedDict
import sys
from select import select
import subprocess

sys.path.insert(0, "../common")

import time
import leds
import beeper
from wbmqtt import WBMQTT

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




class TestWBIO(unittest.TestCase):
    NUM_CHANNELS = 8

    def _set_out_state(self, channel, state):
        control ='EXT1_K%d' % channel
        val = '1' if state else '0'

        current_val = wbmqtt.get_last_or_next_value('wb-gpio', control)
        # print "Current: %s==%s, requested: %s"  % (channel, current_val, val)
        if current_val != val:
            wbmqtt.send_value('wb-gpio', control, val)
            new_val = wbmqtt.get_next_or_last_value('wb-gpio', control, timeout=0.1)
            self.assertEquals(new_val, val)

    def _get_in_state(self, channel, timeout=0.1):
        control = 'EXT2_DR%d' % channel
        val = wbmqtt.get_next_or_last_value('wb-gpio', control, timeout=timeout)

        self.assertIsNotNone(val)
        self.assertIn(val, ['1','0'])

        return (val == '1')

    def _set_single_channel(self, channel, state):
        """ Sets the specified channel to @state,
        while setting other channels to inverse of @state"""

        for i in xrange(1, self.NUM_CHANNELS + 1):
            if i == channel:
                self._set_out_state(i, state)
            else:
                self._set_out_state(i, not state)


    def _test_single_channel(self, channel, polarity):
        self._set_single_channel(channel, polarity)
        self.assertEqual(self._get_in_state(channel), polarity)

    def _test_single_channel_toggle_state(self, channel, polarity):
        self._set_out_state(channel, polarity)

        if polarity:
            # the delay is here
            # to check if the switching element won't turn back off
            time.sleep(0.1) 
        else:
            time.sleep(0.05) 

        self.assertEqual(
            self._get_in_state(channel, timeout=0.05),
            polarity,
            "I/O channel %d: input erroneously reports %s state" % (channel, not polarity))

    def _test_single_channel_multiple_toggle(self, channel, repetitions):
        # start with off state
        self._set_out_state(channel, False)
        # wait to settle
        try:
            for i in xrange(repetitions):
                self._test_single_channel_toggle_state(channel, True)
                self._test_single_channel_toggle_state(channel, False)
        except Exception as e:
            self._set_out_state(channel, False)
            raise e


    def _test_all_multiple_toggle(self, repetitions):
        failed_channels = set()
        for i in xrange(repetitions):
            for chan in xrange(1, self.NUM_CHANNELS + 1):
                self._set_out_state(chan, False);

            time.sleep(0.1)

            for chan in xrange(1, self.NUM_CHANNELS + 1):
                self._set_out_state(chan, True);

            time.sleep(0.1)

            for chan in xrange(1, self.NUM_CHANNELS + 1):
                if not self._get_in_state(chan, timeout=0.001):
                    failed_channels.add(chan)




    def _test_single_channel_alt(self, channel):
        for i in xrange(1, self.NUM_CHANNELS + 1):
            self._set_out_state(i, False)

        self.assertEqual(
            self._get_in_state(channel, timeout = 0.3), False,
                    "I/O channel %d: input erroneously reports on state" % channel)

        self._test_single_channel_toggle_state(channel, True)
        time.sleep(0.1)

        for i in xrange(1, self.NUM_CHANNELS + 1):
            if i != channel:
                self.assertEqual(
                    self._get_in_state(i, timeout=0.01),
                    False,
                    "Possible crosstalk between channels %d and %d" % (channel, i))

        self._set_out_state(channel, False)

    # def _test_single_channel_off(self, channel):
    #     self._set_out_state(channel, False)





from functools import partial



class TestWBIO16(TestWBIO):
    NUM_CHANNELS = 16

for i in xrange(1, TestWBIO16.NUM_CHANNELS + 1):
    setattr(TestWBIO16, 'test_1_pos_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_alt(i))(i))

class TestR1G16(TestWBIO16):
    pass
    # def test_all_multiple_toggle(self):
    #     self._test_all_multiple_toggle(10)
for i in xrange(1, TestWBIO16.NUM_CHANNELS + 1):
    setattr(TestWBIO16, 'test_2_toggle_ch%s' % str(i).zfill(2) ,
        (lambda i: lambda self: self._test_single_channel_multiple_toggle(i, 10))(i))
    


if __name__ == '__main__':
    wbmqtt = WBMQTT()
    wbmqtt.watch_device('wb-gpio')
    time.sleep(1)
    print "==="

    suite = unittest.TestSuite()
    suite.addTest(unittest.makeSuite(TestR1G16))
    failfast = False
    beep = beeper.Beeper(3)
    beep.setup()

    # if has_real_errors:
    # else:
    
    while 1:
        # subprocess.call("service wb-homa-gpio restart", shell=True)
        subprocess.call("service wb-homa-gpio stop ; for i in `seq 256 400`; do echo $i > /sys/class/gpio/unexport ; done ; modprobe  -r gpio_mcp23s08 ; modprobe  gpio_mcp23s08 && service wb-homa-gpio start", shell=True)

        time.sleep(2)

        leds.set_brightness('green', 0)
        leds.set_brightness('red', 0)
        beep.beep(0.05, 1)



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

