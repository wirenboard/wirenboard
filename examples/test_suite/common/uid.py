import re
import os


def get_cpuinfo_serial():
    data = open('/proc/cpuinfo').read()
    matches = re.findall('^Serial\s+: ([0-9a-f]+)$', data, re.M)
    if len(matches) > 0:
        return matches[0]
    return None


def get_mac():
    return os.popen('wb-gen-serial').read().strip()


if __name__ == '__main__':
    print "/proc/cpuinfo serial: ", get_cpuinfo_serial()
    print "WB serial (eth mac): ", get_mac()
