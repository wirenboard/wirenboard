# coding: utf-8
import unittest

import os
import binascii
import serial
import time


# coding: utf-8
import unittest

import os
import serial



class TestRS485(unittest.TestCase):
    port_1 = '/dev/ttyNSC0'
    port_2 = '/dev/ttyNSC1'

    def _open_port(self, port):
        ser = serial.Serial(port, 38400, timeout=3, parity='N',xonxoff=0, rtscts=0, stopbits=1)
        ser.flush()
        ser.flushInput()
        ser.flushOutput()
        return ser



    def _test_echo(self, port_tx, port_rx):
        ser_tx = self._open_port(port_tx)
        ser_rx = self._open_port(port_rx)

        data_to_write = '1234\n'

        time.sleep(200E-3)

        ser_tx.write(data_to_write)
        #~ self.ser_tx.flush()
        data = ser_rx.readline()


        ser_tx.close()
        ser_rx.close()

        self.assertEqual(data, data_to_write, " %s=>%s RS485 ERROR\nTransmitted %s\nReceived: %s"  % (port_tx, port_rx , data_to_write, data))


    def test_echo_12(self):
        self._test_echo(self.port_1, self.port_2)

    def test_echo_21(self):
        self._test_echo(self.port_2, self.port_1)




if __name__ == '__main__':
    unittest.main()

