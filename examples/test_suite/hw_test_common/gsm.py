# coding: utf-8

from wb_common import gsm
import unittest
import re
import subprocess
import time

from gsmmodem.modem import GsmModem

# import logging
# logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.DEBUG)

class TestGSM(unittest.TestCase):
    MIN_SIGNAL_STRENGTH = 21

    @classmethod
    def setUpClass(cls):
        open("/etc/gammurc", "wt").write("[gammu]\nport = /dev/ttyAPP0\nconnection = at115200\n")

    def _init_modem(self):
        gsm.init_gsm()

        self.modem = GsmModem('/dev/ttyAPP0')
        self.modem.connect()

    def setUp(self):
        self._init_modem()

    def tearDown(self):
        self.modem.close()

    def test_registration(self):
        timeout = 10 # seconds
        csq = self.modem.waitForNetworkCoverage(timeout)
        self.assertGreaterEqual(csq, self.MIN_SIGNAL_STRENGTH)


class TestGSMRTC(unittest.TestCase):
#~ class TestGSMRTC(object): # disable

    RTC_TIMEOUT_SECONDS = 2

    def test_rtc(self):
        gsm.init_gsm()

        # large capacitor parallel to battery in WB4 prevent it from working...

        subprocess.call("wb-gsm-rtc save_time", shell=True)

        subprocess.call("wb-gsm off", shell=True)
        rtc_timeout = self.RTC_TIMEOUT_SECONDS

        print "Sleep for %s seconds to allow RTC cap to discarge" % rtc_timeout
        time.sleep(rtc_timeout)
        gsm.init_gsm()

        proc = subprocess.Popen('wb-gsm-rtc read', shell=True, stdout=subprocess.PIPE)
        stdout, stderr = proc.communicate()

        time_read = stdout
        print "read back: ", time_read

        year = int(time_read.split('/')[0])
        self.assertGreater(year, 10)

if __name__ == '__main__':
    unittest.main()
