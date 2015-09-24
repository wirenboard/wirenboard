# coding: utf-8
import unittest

import os
import random, string

from nrf24 import Nrf24


class TestNrf24Base(unittest.TestCase):
    CE_PIN = None
    SPI_MINOR = None


    def setUp(self):
        self.assertIsNotNone(self.CE_PIN)
        self.assertIsNotNone(self.SPI_MINOR)

    def test_dev_presense(self):
        nrf = Nrf24(cePin=self.CE_PIN,spiMajor=0, spiMinor=self.SPI_MINOR,channel=3,payload=15)

        taddr = "h-"  + "".join(random.choice(string.letters) for _ in xrange(3))
        assert len(taddr) == 5

        nrf.config()
        nrf.setTADDR(taddr)
        print nrf.getTADDR()
        self.assertEqual(taddr, nrf.getTADDR())
