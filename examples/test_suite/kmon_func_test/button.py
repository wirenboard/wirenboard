# coding: utf-8
import unittest

import subprocess
#~ import relay
import time
import os
import sys

class TestProgButton(unittest.TestCase):

    @classmethod
    def setUp(self):
        self.gpio = int(os.environ['WB_GPIO_PROG_BUTTON'])
        #exporting GPIO, switching to "in" state
        open('/sys/class/gpio/export', 'wt').write("%d\n" % self.gpio)
        open('/sys/class/gpio/gpio%d/direction' % self.gpio, 'wt').write("in\n")



    def test_button(self):
        print "============================="
        print "Press front panel button"
        print "============================="

        max_waiting_time_s = 10
        iter_delay_s = 0.1

        for i in xrange(int(max_waiting_time_s / iter_delay_s) + 1):
            val = int(open('/sys/class/gpio/gpio%d/value' % self.gpio).read().strip())
            if val == 0:
                print
                return

            sys.stdout.write('.')
            sys.stdout.flush()
            time.sleep(iter_delay_s)

        print

        self.assertTrue(False, "prog button error")



if __name__ == '__main__':
    unittest.main()

