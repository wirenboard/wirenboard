# coding: utf-8
import unittest
import time
import subprocess
from subprocess import Popen, PIPE

class ADC(object):
    N_SAMPLES=30
    def setup(self):
        subprocess.call("killall -9 wb-homa-adc", shell=True)


    def set_scale(self, channel, scale):
        open('/sys/bus/iio/devices/iio:device0/in_voltage%d_scale' % channel, 'wt').write(scale + '\n')

    def get_available_scales(self, channel):
        return open('/sys/bus/iio/devices/iio:device0/in_voltage%d_scale_available' % channel).read().strip().split()

    def read_mux_value(self, mux_ch):
        subprocess.call("wb-adc-set-mux %d" % mux_ch, shell=True)
        time.sleep(100E-3)
        return self.read_phys_ch_value(1)

    def read_mux_value_with_source(self, mux_ch, current):

        subprocess.call("wb-adc-set-mux %d" % mux_ch, shell=True)
        time.sleep(100E-3)
        subprocess.call("lradc-set-current %duA" % current, shell=True)
        time.sleep(10E-3)


        value = self.read_phys_ch_value(1)
        subprocess.call("lradc-set-current off" , shell=True)

        return value




    def read_phys_ch_value(self, channel):
        values = []
        for i in xrange(self.N_SAMPLES):
            v = int(open('/sys/bus/iio/devices/iio:device0/in_voltage%d_raw' % channel).read())
            values.append(v)
            #~ time.sleep(20)
        return 1.0 * sum(values) / len(values)

