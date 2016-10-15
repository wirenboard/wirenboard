# coding: utf-8
import os
import subprocess


def gsm_decode(hexstr):
    return os.popen('echo %s | xxd -r -ps | iconv -f=UTF-16BE -t=UTF-8' % hexstr).read()


def init_gsm():
    retcode = subprocess.call("wb-gsm restart_if_broken", shell=True)
    if retcode != 0:
        raise RuntimeError("gsm init failed")

def init_baudrate():
    retcode = subprocess.call("wb-gsm init_baud", shell=True)
    if retcode != 0:
        raise RuntimeError("gsm init baudrate failed")

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
