#!/usr/bin/env python

#http://www.raspberrypi.org/forums/viewtopic.php?f=32&t=12632&sid=e55f5659c8e2006e69fb22862cbb4875&start=25


#green/data0 is gpio 5 (R4 at WB3.3)
#white/data1 is gpio 6 (R3 at WB3.3)
D0 = 5
D1 = 6

import time
import WB_IO.GPIO as GPIO



bits = ''
t = 15
timeout = t

#~ GPIO.setmode(GPIO.BOARD)
GPIO.setup(D0, GPIO.IN)
GPIO.setup(D1,GPIO.IN)

def set_procname(newname):
	from ctypes import cdll, byref, create_string_buffer
	libc = cdll.LoadLibrary('libc.so.6')    #Loading a 3rd party library C
	buff = create_string_buffer(len(newname)+1) #Note: One larger than the name (man prctl says that)
	buff.value = newname                 #Null terminated string as it should be
	libc.prctl(15, byref(buff), 0, 0, 0) #Refer to "#define" of "/usr/include/linux/prctl.h" for the misterious value 16 & arg[3..5] are zero as the man page says.

def one(channel):
	global bits
	global timeout
	bits = bits + '1'
	timeout = t

def zero(channel):
	global bits
	global timeout
	bits = bits + '0'
	timeout = t



def main():
	set_procname("Wiegand Reader")
	global bits
	global timeout
	GPIO.add_event_detect(D0, GPIO.FALLING, callback=zero)
	GPIO.add_event_detect(D1, GPIO.FALLING, callback=one)
	while 1:
		if bits:
			timeout = timeout -1
			time.sleep(0.001)
			if len(bits) > 1 and timeout == 0:
				print "Binary:",bits
				result = int(str(bits),2)
				print result

				bits = '0'
				timeout = t


		else:
			time.sleep(0.001)



if __name__ == '__main__':
	main()
