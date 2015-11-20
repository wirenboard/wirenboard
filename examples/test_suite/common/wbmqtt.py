#!/usr/bin/python
import mosquitto
import time
import sys

from collections import defaultdict

VALUES_MASK = "/devices/+/controls/+"
class WBMQTT(object):
    def __init__(self):
        self.control_values = defaultdict(lambda: None)


        self.client = mosquitto.Mosquitto()
        self.client.connect('localhost',1883)
        self.client.on_message = self.on_mqtt_message
        self.client.loop_start()

        self.client.subscribe(VALUES_MASK)



    def on_mqtt_message(self, arg0, arg1, arg2=None):
        if arg2 is None:
            mosq, obj, msg = None, arg0, arg1
        else:
            mosq, obj, msg = arg0, arg1, arg2

        if mosquitto.topic_matches_sub(VALUES_MASK, msg.topic):
            parts = msg.topic.split('/')
            device_id = parts[2]
            control_id = parts[4]

            self.control_values[(device_id, control_id)] = msg.payload

    def clear_values(self):
        self.control_values.clear()

    def get_last_value(self, device_id, control_id):
        return self.control_values[(device_id, control_id)]

    def get_next_value(self, device_id, control_id, timeout = 10):
        self.control_values[(device_id, control_id)] = None
        ts_start = time.time()
        while 1:
            if (time.time() - ts_start) >  timeout:
                return

            value = self.get_last_value(device_id, control_id)
            if value is not None:
                return value

            time.sleep(0.01)


    def send_value(self, device_id, control_id, new_value, retain=False):
        self.client.publish("/devices/%s/controls/%s/on" % (device_id, control_id), new_value, retain=retain)

    def close(self):
        self.client.loop_stop()

    def __del__(self):
        self.close()

if __name__ == '__main__':

    time.sleep(1)
    print wbmqtt.get_last_value('wb-adc', 'A1')
    wbmqtt.close()







