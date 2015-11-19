# coding: utf-8
import unittest

import os
import binascii
import serial
import time
import subprocess
import threading

class CanPort(object):
    def __init__(self, iface = 'can0', bitrate=115200):
        self.iface = iface
        self.bitrate = bitrate
        
        self.receive_ready = threading.Event()
        self.receive_thread = None
        
    def setup(self):
        # re-initialize iface
        subprocess.call("ifconfig %s down" % self.iface, shell=True)
        subprocess.call("ip link set %s type can bitrate 125000" % self.iface, shell=True)
        subprocess.call("ifconfig %s up" % self.iface, shell=True)
        
    def send(self, addr, data):
        addr_str = hex(addr)[2:][:3].zfill(3)
        data_str = binascii.hexlify(data)
        subprocess.call("cansend %s %s#%s" % (self.iface , addr_str, data_str), shell=True)

    def receive(self, timeout_ms = 1000):
        proc = subprocess.Popen("candump  %s -s0 -L -T %s" % (self.iface, timeout_ms) , shell=True, stdout=subprocess.PIPE)
        stdout, stderr = proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError("candump failed")
    
        stdout_str = stdout.strip()
        frames = []
        for line in stdout_str.split('\n'):
            line = line.strip()
            if line:
                parts = line.split(' ')
                if len(parts) == 3:
                    ts, iface, packet = parts
                    addr_str, data_str = packet.split('#')
                    addr = int(addr_str, 16)
                    data = binascii.unhexlify(data_str)
                    frames.append((addr, data))
        return frames

    def _receiver_work(self, timeout_ms):
        frames = self.receive(timeout_ms)
        self._frames = frames
    
    def start_receive(self, timeout_ms = 1000):
        self.receive_thread = threading.Thread(target=self._receiver_work, args=(timeout_ms,))
        self.receive_thread.start()
    
    def get_received_data(self):
        self.receive_thread.join()
        return self._frames
        
        
    

class TestCAN(unittest.TestCase):
    port_1 = 'can0'
    port_2 = 'can1'

    @classmethod
    def setUpClass(cls):
        pass

    def _open_port(self, iface):
        port =  CanPort(iface)
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
           
