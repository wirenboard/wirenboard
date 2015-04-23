# coding: utf-8
import unittest

import subprocess
import relay

list_of_gpio = [60,136,135,134,56,55,23,25,16,17,54,57,53,5,6,7,38,39,1,2,36,37]


class TestGPIO(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        #exporting GPIO, switching to "in" state
        for i in range (0,22):
            subprocess.call("echo -n " + str(list_of_gpio[i]) + " > /sys/class/gpio/export", shell=True)
            subprocess.call("echo in > /sys/class/gpio/gpio" + str(list_of_gpio[i]) + "/direction", shell=True)

        #switching izolated power on
        subprocess.call("echo -n 133 > /sys/class/gpio/export", shell=True)
        subprocess.call("echo out > /sys/class/gpio/gpio133/direction", shell=True)
        subprocess.call("echo 1 > /sys/class/gpio/gpio133/value", shell=True)


    def _test_single(self, num, relay_num, state):
        val = int(open("/sys/class/gpio/gpio"+str(list_of_gpio[num])+"/value","r").read())

        self.assertEqual(val, state, "Dry input "+str(num+1)+" does not work with relay K"+str(relay_num))

        #~ relay.off(relay_num)


    def test_all(self):
        for j in range (3, 5):
            relay.on(j)
            for i in range (0, 22):
                self._test_single(i, j, 0)
            relay.off(j)
            for i in range (0, 22):
                self._test_single(i, j, 1)








if __name__ == '__main__':
    relay.init()
    unittest.main()



