# coding: utf-8
import unittest

import subprocess
import os
import re


def get_wlan_ifaces():
    ifaces = os.listdir('/sys/class/net/')
    wlan_ifaces = [x for x in ifaces if x.startswith('wlan')]
    return wlan_ifaces

def get_wlan_mac():
    ifaces = get_wlan_ifaces()
    if ifaces:
        try:
            return open('/sys/class/net/%s/address' % ifaces[0]).read().strip()
        except:
            return None
    else:
        return None

class TestWifi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.call("killall -9 hostapd", shell=True)

    def setUp(self):
        pass

    def test_wifi_presence(self):
        wlan_ifaces = get_wlan_ifaces()
        self.assertEqual(len(wlan_ifaces), 1)

    def test_iwlist(self):
        essid = 'contactless.ru'

        wlan_ifaces = get_wlan_ifaces()
        iface = wlan_ifaces[0]
        subprocess.call("ifconfig %s up" % iface, shell=True)

        proc = subprocess.Popen("iwlist %s scan" % iface, stdout=subprocess.PIPE, shell=True)
        stdout, stderr = proc.communicate()

        self.assertIn('ESSID:"%s"' % essid, stdout)

        matches = re.findall('ESSID:"%s".*?Signal level(.*?)\s' % essid, stdout, re.S)
        self.assertEqual(len(matches), 1)

        #~ m = re.match('^=(\d+)/\d+$',  matches[0])
        #~ self.assertIsNotNone(m)
        #~ signal_level = int(m.group(1))
        #~ self.assertGreater(signal_level, 20)

    #~ def test_ping(self):
        #~ proc = subprocess.Popen("ping -w 10 -c 3 8.8.8.8", shell=True)
        #~ stdout, stderr = proc.communicate()
#~
        #~ self.assertEqual(proc.returncode, 0)


if __name__ == '__main__':
    unittest.main()
