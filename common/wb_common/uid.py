import re
import os

def get_cpuinfo_serial():
    data = open('/proc/cpuinfo').read()
    matches = re.findall('^Serial\s+: ([0-9a-f]+)$', data, re.M)
    if len(matches) > 0:
        return matches[0]
    return None


def get_mmc_serial():
    mmc_prefix = '/sys/class/mmc_host/mmc0/'
    if os.path.exists(mmc_prefix):
        for entry in os.listdir(mmc_prefix):
            if entry.startswith('mmc'):
                serial_fname = mmc_prefix + entry + '/serial'
                if os.path.exists(serial_fname):
                    serial = open(serial_fname).read().strip()
                    if serial.startswith('0x'):
                        serial = serial[2:]
                    return serial
    return None

def get_mac():
    return os.popen('wb-gen-serial').read().strip()


if __name__ == '__main__':
    print "/proc/cpuinfo serial: ", get_cpuinfo_serial()
    print "WB serial (eth mac): ", get_mac()
