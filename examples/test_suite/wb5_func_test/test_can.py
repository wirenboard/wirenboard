# coding: utf-8

from wb_common.can import CanPort

import time
import unittest


class TestCAN(unittest.TestCase):
    port_1 = 'can0'
    port_2 = 'can1'

    @classmethod
    def setUpClass(cls):
        pass

    def _open_port(self, iface):
        port = CanPort(iface)
        port.setup()
        return port


    def _test_echo(self, port_tx, port_rx):
        ser_tx = self._open_port(port_tx)
        ser_rx = self._open_port(port_rx)

        data_to_write = '1234\n'
        addr = 123
        ser_rx.start_receive(500)

        time.sleep(100E-3)

        ser_tx.send(addr, data_to_write)
        #~ self.ser_tx.flush()
        frames = ser_rx.get_received_data()


        self.assertEqual(len(frames), 1, " %s=>%s CAN ERROR\n received %d frames instead of 1" % (port_tx, port_rx, len(frames) ))

        self.assertEqual(frames[0][0], addr)
        self.assertEqual(frames[0][1], data_to_write)


    def test_echo_12(self):
        self._test_echo(self.port_1, self.port_2)

    def test_echo_21(self):
        self._test_echo(self.port_2, self.port_1)


if __name__ == '__main__':
    unittest.main()
#~
#~ if __name__ == '__main__':
    #~ port = CanPort('can0')
    #~ port.send(123, 'abcdef')
    #~ print port.receive()

