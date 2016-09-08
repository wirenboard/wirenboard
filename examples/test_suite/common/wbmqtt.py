#!/usr/bin/python
import mosquitto
import time

from collections import defaultdict
import logging

VALUES_MASK = "/devices/+/controls/+"
ERRORS_MASK = "/devices/+/controls/+/meta/error"

class CellSpec(object):
    def __init__(self, value = None, error = None):
        self.value = value
        self.error = error

class WBMQTT(object):
    def __init__(self):
        self.control_values = defaultdict(lambda: CellSpec())

        self.client = mosquitto.Mosquitto()
        self.client.connect('localhost', 1883)
        self.client.on_message = self.on_mqtt_message
        self.client.loop_start()

        self.device_subscriptions = set()
        self.channel_subscriptions = set()

        # self.client.subscribe(VALUES_MASK)
        # self.client.subscribe(ERRORS_MASK)

    @staticmethod
    def _get_channel_topic(device_id, control_id):
        return '/devices/%s/controls/%s' % (device_id, control_id)

    def watch_device(self, device_id):
        if device_id in self.device_subscriptions:
            return
        else:
            topic = self._get_channel_topic(device_id, '+')
            self.client.subscribe(topic)
            self.client.subscribe(topic + '/meta/error')
            self.device_subscriptions.add(device_id)

    def watch_channel(self, device_id, control_id):
        if device_id in self.device_subscriptions:
            return
        if (device_id, control_id) in self.channel_subscriptions:
            return

        topic = self._get_channel_topic(device_id, control_id)
        self.client.subscribe(topic)
        self.client.subscribe(topic + '/meta/error')
        self.channel_subscriptions.add((device_id, control_id))

    def unwatch_channel(self, device_id, control_id):
        topic = self._get_channel_topic(device_id, control_id)
        self.client.unsubscribe(topic)
        self.client.unsubscribe(topic + '/meta/error')

    @staticmethod
    def _get_channel(topic):
        parts = topic.split('/')
        device_id = parts[2]
        control_id = parts[4]
        return device_id, control_id

    def on_mqtt_message(self, arg0, arg1, arg2=None):
        if arg2 is None:
            mosq, obj, msg = None, arg0, arg1
        else:
            mosq, obj, msg = arg0, arg1, arg2
        if msg.retain:
            return
        if mosquitto.topic_matches_sub(VALUES_MASK, msg.topic):
            self.control_values[self._get_channel(msg.topic)].value = msg.payload
        elif mosquitto.topic_matches_sub(ERRORS_MASK, msg.topic):
            self.control_values[self._get_channel(msg.topic)].error = msg.payload or None

    def clear_values(self):
        for cell_spec in self.control_values.itervalues():
            cell_spec.value = None

    def get_last_value(self, device_id, control_id):
        return self.control_values[(device_id, control_id)].value

    def get_last_or_next_value(self, device_id, control_id):
        val = self.get_last_value(device_id, control_id)
        if val is not None:
            return val
        else:
            return self.get_next_value(device_id, control_id)

    def get_last_error(self, device_id, control_id):
        self.watch_channel(device_id, control_id)
        return self.control_values[(device_id, control_id)].error

    def get_next_value(self, device_id, control_id, timeout=10):
        self.watch_channel(device_id, control_id)
        self.control_values[(device_id, control_id)].value = None
        ts_start = time.time()
        while 1:
            if (time.time() - ts_start) > timeout:
                return

            value = self.get_last_value(device_id, control_id)
            if value is not None:
                return value

            time.sleep(0.01)

    def get_stable_value(self, device_id, control_id, timeout=30, jitter=10): 
        start = time.time()
        last_val = None
        while time.time() - start < timeout:
            val = float(self.get_next_value(device_id, control_id))
            if last_val is not None:
                if abs(val - last_val) < jitter:
                    return val
            last_val = val

        return last_val

    def get_average_value(self, device_id, control_id, interval=1):
        start = time.time()
        val_sum = 0.0
        val_count = 0

        while time.time() - start <= interval:
            val = self.get_next_value(device_id, control_id, timeout=interval)
            if val is not None:
                try:
                    val_sum += float(val)
                except ValueError:
                    logging.warning("cannot convert %s to float while calculating average" % val)
                    continue
                else:
                    val_count += 1
        if val_count > 0:
            return val_sum / val_count
        else:
            return None

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
