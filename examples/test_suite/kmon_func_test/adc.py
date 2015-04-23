# coding: utf-8
import unittest

import subprocess
import relay
from subprocess import Popen, PIPE



class TestADC(unittest.TestCase):
    def setUp(self):
        pass

    def read_value(self, num):
        subprocess.call("wb-adc-set-mux " + str(num), shell=True)
        process = Popen(['wb-adc-get-value'], stdout=PIPE, stderr=PIPE, shell=True)
        stdout, stderr = process.communicate()
        return int(stdout)

    def _test_single(self, num, relay_num, state):
        value = self.read_value(num)
        if state==0:
            self.assertLess(value, 100, "ADC"+str(num+1)+" does not work with relay K"+str(relay_num))
            #~ relay.off(relay_num)

        if state==1:
            msg  = "ADC"+str(num+1)+" does not work with relay K"+str(relay_num)

            self.assertLess(value, 1500, msg)
            self.assertGreater(value, 1300, msg)
            #~ relay.off(relay_num)


    def test_all(self):
        for j in range (1,3):
            relay.on(j)
            for i in range (0,8):
                self._test_single(i,j,1)
            relay.off(j)
            for i in range (0,8):
                self._test_single(i,j,0)

        return True





if __name__ == '__main__':
    unittest.main()

