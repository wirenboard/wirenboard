# coding: utf-8

import binascii
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

