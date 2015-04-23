# coding: utf-8
import unittest

import subprocess
import os




class TestNetwork(unittest.TestCase):
    def setUp(self):
        pass

    def test_ping(self):
        proc = subprocess.Popen("ping -w 10 -c 3 8.8.8.8", shell=True)
        stdout, stderr = proc.communicate()

        self.assertEqual(proc.returncode, 0)




if __name__ == '__main__':
    unittest.main()

