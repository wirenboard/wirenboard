#!/usr/bin/python
try:
    import mosquitto
except ImportError:
    import paho.mqtt.client as mosquitto
import logging
import time
import serial
import threading
import re

logging.getLogger('').setLevel(logging.DEBUG)

class WbMqttHandler(object):
    def _on_mqtt_message(self, mosq, obj, msg):
        logging.debug("got mqtt message on topic %s" % msg.topic)
        if not mosquitto.topic_matches_sub('/devices/+/controls/#', msg.topic):
            return

        parts = msg.topic.split('/')
        device_id = parts[2].decode('utf8')
        control_id = parts[4].decode('utf8')

        channel = (device_id, control_id)

        # ignore retained values
        if msg.retain:
            return

        logging.debug("%s/%s <= %s" % (channel[0], channel[1], msg.payload))
        self.on_channel_value(self._format_channel(channel), msg.payload)


    def _parse_channel(self, channel_str):
        channel = channel_str.split('/', 1)
        if len(channel) != 2:
            raise RuntimeError("wrong channel spec %s" % channel_str)
        return tuple(channel)

    def _format_channel(self, channel):
        assert len(channel) == 2
        return "%s/%s" % channel


    def on_channel_value(self, channel, value):
        """ to be redefined in user classes """
        logging.info("%s/%s <= %s" % (channel[0], channel[1], value))

    def set_channel_value(self, channel_str, value):
        channel = self._parse_channel(channel_str)
        topic = "/devices/%s/controls/%s/on" % channel
        self.client.publish(topic, str(value), qos=2, retain=False)

    def __init__(self, subscribe_channels = []):
        self.client = mosquitto.Mosquitto()
        self.client.connect("127.0.0.1", 1883)
        self.client.on_message = self._on_mqtt_message
        self.client.loop_start()
        for channel_str in subscribe_channels:
            channel = self._parse_channel(channel_str)
            self.client.subscribe("/devices/%s/controls/%s" % channel)
            print "/devices/%s/controls/%s" % channel


class Matrix3NetworkHandler(object):
    """ handles a network of Matrix III RD-ALL readers 
    connected to a single RS-485 bus.

    The readers must be prepared by flasing the special firmware first:
    http://www.ironlogic.ru/il.nsf/file/ru_rdall_net.rar/$FILE/rdall_net.rar
    """



    def __init__(self, port, timeout=1):
        self.port = serial.Serial(port = port,
            baudrate=9600, parity=serial.PARITY_NONE, 
            stopbits=serial.STOPBITS_ONE,
            timeout=timeout)

        self.reader_thread = threading.Thread(target=self.reader_loop)
        self.reader_thread.daemon = True
        self.reader_thread.start()

        self.card_pattern = re.compile(r'^([^[]+)\[([0-9A-F]+)\] ([^ ]*) ?(?:\(([^,]+),([^,]+)\))? ?(\d{3}),(\d{5})$')


    def parse_reply(self, line):
        """ Processes the message sent by Matrix III reader in
        network mode. Returns None if the reply cannot by parsed,
        and tuple of (reader_id, message) otherwise """

        # format:
        # UUUUU <everything else>
        # UUUUU is a reader id

        match = re.match("^(\d{5}) (.*)$", line)
        if not match:
            return None

        reader_id = int(match.group(1))
        message = match.group(2)

        return reader_id, message

    def parse_card_message(self, msg):
        """ Parses the reader answer about the card in field, if any.
        Returns None if no card present,
        a tuple (card_type, card_number) otherwise
        """

        # Examples of card messages:
        # No Card
        # Mifare[3AAC2280045646]  (0142,20) 004,22086
        # Mifare[3AAC228004724B]  (0142,20) 004,29259
        # Mifare[A24B3180044807]  (0144,10) 004,18439
        # Mifare[77242CF0]  (0004,88) 044,09335
        # Mifare[FA592F830412E6] UL (0144,00) 004,04838
        # Mifare[F2D329830409B6] UL (0144,00) 004,02486
        # Mifare[2A223182048F18] UL (0144,00) 004,36632
        # Mifare[F274238004DEC2] UL (0144,00) 004,57026
        # Mifare[81895266340051] UL (0144,00) 052,00081
        # Mifare[BCD14264] 1K (0004,08) 066,53692
        # Mifare[24548AAC] 1K (0004,08) 138,21540
        # Mifare[9DCB4340] 1K (0004,08) 067,52125
        # Mifare[124A2D80042C27] DF (0144,20) 004,11303
        # Em-Marine[5500] 126,58404

        if msg == 'No Card':
            return None

        logging.debug("got card message: '%s'" % msg)
        match = re.match(self.card_pattern, msg)
        if not match:
            logging.warning("unknown card message: %s" % msg)
            return None
        card_type = match.group(1)
        card_subtype = match.group(3)
        serial_1 = match.group(2)
        serial_2 = match.group(6)
        serial_3 = match.group(7)

        serial_23_hex = hex(int(serial_2)*0xFF + int(serial_3))[2:].upper()


        if card_type == 'Mifare':
            # serial_2 and serial_3 are 3 last bytes of the serial_1, ignoring
            serial = serial_1
        else:
            serial = serial_1 + serial_23_hex

        return (card_type + card_subtype, serial)


    def process_async_message(self, msg):
        """ Processes the message sent by Matrix III reader
        for a new card detected in field """

        # example reader message:
        #  19997 Mifare[62D22F80041B4B]  (0144,08) 004,06987

        reply = self.parse_reply(msg)
        if reply:
            reader_id, card_message = reply
            card_info = self.parse_card_message(card_message)
            if card_info:
                card_type, card_serial = card_info

                logging.debug("Reader %s: new card %s[%s] in field" % (reader_id, card_serial, card_type))
                self.on_new_card(reader_id, card_type, card_serial)

    def reader_loop(self):
        while True:
            line = self.port.readline()
            if line:
                self.process_async_message(line[:-2])

    def on_new_card(self, reader_id, card_type, card_serial):
        """ to be ovverriden by user """
        logging.info("Reader %s: new card %s[%s] in field" % (reader_id, card_serial, card_type))

class TurnstilesManager(object):
    def on_pass_signal(self, channel, value):
        if value != '1':
            return

        for turnstile in self.turnstiles:
            if channel == turnstile['pass_status_channel']:
                logging.info("Pass signal detected for turnstile %s" % turnstile['name'])
                break

    def on_new_card(self, reader_id, card_type, card_serial):
        logging.info("Reader %s: new card %s[%s] in field" % (reader_id, card_serial, card_type))

        for turnstile in self.turnstiles:
            if reader_id == turnstile['reader_id']:
                allow_open = int(card_serial, 16) % 2 == 0
                if allow_open:
                    logging.info("Turnstile %s: opening the gate" % turnstile['name'])

                    self.mqtt_handler.set_channel_value(turnstile['open_channel'], '1')
                    time.sleep(100E-3)
                    self.mqtt_handler.set_channel_value(turnstile['open_channel'], '0')
                else:
                    logging.info("Turnstile %s: access denied!" % turnstile['name'])

                break
        else:
            logging.error("unknown reader id: %s" % reader_id)







    def __init__(self, turnstiles):
        self.turnstiles = turnstiles


        status_channels = [turnstile['pass_status_channel'] for turnstile in self.turnstiles]

        self.mqtt_handler = WbMqttHandler(subscribe_channels = status_channels)
        self.readers_handler = Matrix3NetworkHandler(port='/dev/ttyAPP4')

        self.mqtt_handler.on_channel_value = self.on_pass_signal
        self.readers_handler.on_new_card = self.on_new_card

            



if __name__ =='__main__':

    manager = TurnstilesManager(turnstiles = [
        {
            'name' : 'Turnstile 1 forward',
            'reader_id' : 3794,
            'pass_status_channel' : 'wb-gpio/A1_IN',
            'open_channel' : 'wb-gpio/EXT1_R3A1'
        },
        {
            'name' : 'Turnstile 1 backwards',
            'reader_id' : 12609,
            'pass_status_channel' : 'wb-gpio/A2_IN',
            'open_channel' : 'wb-gpio/EXT1_R3A2'
        },

    ])



    # mqtt_handler = WbMqttHandler(subscribe_channels = [ "wb-gpio/A1_IN", "wb-gpio/A2_IN" ])
    # readers_handler = Matrix3NetworkHandler(port='/dev/ttyAPP4')

    time.sleep(1E100)