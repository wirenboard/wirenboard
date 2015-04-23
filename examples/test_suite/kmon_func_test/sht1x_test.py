# coding: utf-8
import unittest

import subprocess
import re
import os




class TestSht1x(unittest.TestCase):
    def setUp(self):
        os.system('sh /etc/init.d/wb-mqtt-sht1x stop')

    def test_sht1x(self):
        proc = subprocess.Popen("/usr/bin/sht1x", shell=True, stdout=subprocess.PIPE)
        stdout, stderr = proc.communicate()

        self.assertEqual(proc.returncode, 0)

        print "stdout: ", stdout
        match = re.match('^Temperature: (\d+\.?\d*) Humidity: (\d+\.?\d*)', stdout)
        self.assertTrue(bool(match))


        temp = float(match.group(1))
        hum = float(match.group(2))
        print "temp=%s, hum=%s" % (temp, hum)

        self.assertLess(temp, 30)
        self.assertGreater(temp, 20)

        self.assertLess(hum, 60)
        self.assertGreater(temp, 20)

if __name__ == '__main__':
    unittest.main()

