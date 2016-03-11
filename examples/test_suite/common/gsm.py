# coding: utf-8
import os
import re
import unittest
import subprocess
import time


def gsm_decode(hexstr):
    return os.popen('echo %s | xxd -r -ps | iconv -f=UTF-16BE -t=UTF-8' % hexstr).read()


def init_gsm():
    retcode = subprocess.call("wb-gsm restart_if_broken", shell=True)
    if retcode != 0:
        raise RuntimeError("gsm init failed")


def gsm_get_imei():
    proc = subprocess.Popen("wb-gsm imei", shell=True, stdout=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError("get imei failed")

    return stdout.strip()

def split_imei(imei):
    imei = str(imei)
    if not imei.isdigit():
        raise RuntimeError("imei is not a numerical")

    if len(imei) != 15:
        raise RuntimeError("wrong imei len")

    prefix = imei[:8]
    sn = imei[8:14]
    crc = imei[14]

    return int(prefix), int(sn), int(crc)

class TestGSM(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        open("/etc/gammurc", "wt").write("[gammu]\nport = /dev/ttyAPP0\nconnection = at115200\n")


class TestGSMMegafon(TestGSM):
    def test_number(self):
        init_gsm()
        #~ return
        ussd_number = '*205#'
        # ~ ussd_number = '*111*0887#'

        proc = subprocess.Popen('gammu getussd %s' % ussd_number, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        #~ | grep "Service reply" | sed -e "s/.*\"\(.*\)\".*/\1/" | xxd -r -ps | iconv -f=UTF-16BE -t=UTF-8
        stdout, stderr = proc.communicate()

        self.assertEquals(proc.returncode, 0, "Gammu error: " + stdout + stderr)

        matches = re.findall('Service reply\s+:\s+"(.*)"', stdout)

        self.assertTrue(bool(matches))
        self.assertEquals(len(matches), 1)

        ussd_response = gsm_decode(matches[0])
        print "test number stdout: ", ussd_response

        match = re.match('.*(7\d{10}).*', ussd_response)
        self.assertTrue(bool(match), "ussd response: " + ussd_response)

        number = match.group(1)

        self.assertTrue(number.startswith('7'))


class TestGSMMTS(TestGSM):
    def test_number(self):
        init_gsm()
        ussd_number = '*111*0887#'

        # MTS sends SMS following USSD request
        # so delete all sms first

        subprocess.call("gammu deleteallsms  1", shell=True)

        proc = subprocess.Popen('gammu getussd %s' % ussd_number, shell=True, stdout=subprocess.PIPE)
        #~ | grep "Service reply" | sed -e "s/.*\"\(.*\)\".*/\1/" | xxd -r -ps | iconv -f=UTF-16BE -t=UTF-8
        stdout, stderr = proc.communicate()

        self.assertEquals(proc.returncode, 0, "Gammu send USSD error: " + stdout)

        proc = subprocess.Popen('gammu geteachsms', shell=True, stdout=subprocess.PIPE)
        stdout, stderr = proc.communicate()
        self.assertEquals(proc.returncode, 0, "Gammu get SMS error: " + stdout)

        print "Got SMS: ", stdout.decode('utf-8')

        self.assertIn(u'Ваш номер телефона:+', stdout.decode('utf-8'))


class TestGSMRTC(unittest.TestCase):
#~ class TestGSMRTC(object): # disable

    RTC_TIMEOUT_SECONDS = 0

    def test_rtc(self):
        init_gsm()
        
        # large capacitor parallel to battery in WB4 prevent it from working...

        subprocess.call("wb-gsm-rtc save_time", shell=True)

        subprocess.call("wb-gsm off", shell=True)
        rtc_timeout = self.RTC_TIMEOUT_SECONDS

        print "Sleep for %s seconds to allow RTC cap to discarge" % rtc_timeout
        time.sleep(rtc_timeout)
        init_gsm()

        proc = subprocess.Popen('wb-gsm-rtc read', shell=True, stdout=subprocess.PIPE)
        stdout, stderr = proc.communicate()

        time_read = stdout
        print "read back: ", time_read

        year = int(time_read.split('/')[0])
        self.assertGreater(year, 10)


if __name__ == '__main__':
    unittest.main()
