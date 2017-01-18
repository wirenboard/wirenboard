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
wbmqtt = None

class TestDiscreteBase(unittest.TestCase):
    NUM_CHANNELS = None

    @classmethod
    def _prepare(cls):
        return

    @classmethod
    def setUpClass(cls):
        cls._prepare()

        wbmqtt.watch_device(cls.IN_DEVICE_ID)
        wbmqtt.watch_device(cls.OUT_DEVICE_ID)



    def _set_out_state(self, channel, state):
        control =self.OUT_CONTROL_ID_FMT % channel
        val = '1' if state else '0'

        current_val = wbmqtt.get_last_or_next_value(self.OUT_DEVICE_ID, control)
        # print "Current: %s==%s, requested: %s"  % (channel, current_val, val)
        if current_val != val:
            wbmqtt.send_value(self.OUT_DEVICE_ID, control, val)
            new_val = wbmqtt.get_next_or_last_value(self.OUT_DEVICE_ID, control, timeout=0.1)
            self.assertEquals(new_val, val)

    def _get_in_state(self, channel, timeout=0.1):
        control = self.IN_CONTROL_ID_FMT % channel
        val = wbmqtt.get_next_or_last_value(self.IN_DEVICE_ID, control, timeout=timeout)

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

    # def _test_single_channel(self, channel):
    #     self._set_out_state(channel, False)
    #     for polarity in (True, False):
    #         self._set_out_state(channel, polarity)
    #         self.assertEqual(
    #             self._get_in_state(channel, timeout=0.2),
    #             polarity,
    #             "I/O channel %d: input erroneously reports %s state" % (channel, not polarity))

    def _test_single_channel_toggle_state(self, channel, polarity, check_turn_back=True):
        self._set_out_state(channel, polarity)

        if check_turn_back:
            if polarity:
                # the delay is here
                # to check if the switching element won't turn back off
                time.sleep(0.05) 

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




    def _test_single_channel_alt(self, channel, check_turn_back=True):
        for i in xrange(1, self.NUM_CHANNELS + 1):
            self._set_out_state(i, False)

        self.assertEqual(
            self._get_in_state(channel, timeout = 0.3), False,
                    "I/O channel %d: input erroneously reports on state" % channel)

        self._test_single_channel_toggle_state(channel, True, check_turn_back=check_turn_back)
        time.sleep(0.1)

        for i in xrange(1, self.NUM_CHANNELS + 1):
            if i != channel:
                self.assertEqual(
                    self._get_in_state(i, timeout=0.01),
                    False,
                    "Possible crosstalk between channels %d and %d" % (channel, i))

        self._set_out_state(channel, False)
