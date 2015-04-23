import subprocess
import time

list_of_relays = [120,121,122,123,124,125]

def init():
	#exporting relays
	for i in range (0,6):
		subprocess.call("echo -n " + str(list_of_relays[i]) + " > /sys/class/gpio/export", shell=True)
		subprocess.call("echo out > /sys/class/gpio/gpio" + str(list_of_relays[i]) + "/direction", shell=True)

def on(num):
	#switching relay on
	subprocess.call("echo 1 > /sys/class/gpio/gpio"+str(list_of_relays[num-1])+"/value", shell=True)
	time.sleep(0.2)

def off(num):
	#switching relay off
	subprocess.call("echo 0 > /sys/class/gpio/gpio"+str(list_of_relays[num-1])+"/value", shell=True)
	time.sleep(0.2)
