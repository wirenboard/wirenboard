# coding: utf-8
import unittest

import subprocess
import os

class TestNetworkInterface(unittest.TestCase):
    def _get_iface(self):
        raise NotImplemented

    def test_ping(self):
        proc = subprocess.Popen("ping -I%s -i0.1 -w 2 -c 3 8.8.8.8" % self._get_iface(), 
            shell=True)
        stdout, stderr = proc.communicate()
        self.assertEqual(proc.returncode, 0)

class TestEth0(TestNetworkInterface):
    def _get_iface(self):
        return "eth0"

class TestEth1(TestNetworkInterface):
    def _get_iface(self):
        return "eth1"

TestNetwork = TestEth0





if __name__ == '__main__':
    unittest.main()

