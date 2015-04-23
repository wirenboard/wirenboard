import threading
import select
from collections import defaultdict

class GPIOHandler(object):
    IN = "in"
    OUT = "out"
    RISING = "rising"
    FALLING = "falling"
    BOTH = "both"
    NONE = "none"

    def __init__(self):
        self.event_callbacks = {}
        self.gpio_fds = {}

        self.epoll = select.epoll()

        self.polling_thread = threading.Thread(target = self.gpio_polling_thread)
        self.polling_thread.daemon = True
        self.polling_thread.start()

        self.gpio_first_event_fired = defaultdict(lambda: False)

    def gpio_polling_thread(self):
        while True:
            events = self.epoll.poll()
            for fileno, event in events:
                for gpio, fd in self.gpio_fds.iteritems():
                    if fileno == fd.fileno():
                        if self.gpio_first_event_fired[gpio]:
                            #~ print "fire callback"
                            cb = self.event_callbacks.get(gpio)
                            if cb is not None:
                                cb(gpio)
                        else:
                            self.gpio_first_event_fired[gpio] = True


    def export(self, gpio):
        open('/sys/class/gpio/export','wt').write("%d\n" % gpio)

    def setup(self, gpio, direction):
        self.export(gpio)
        open('/sys/class/gpio/gpio%d/direction' % gpio, 'wt').write("%s\n" % direction)

    def _open(self, gpio):
        fd  = open('/sys/class/gpio/gpio%d/value' % gpio, 'r+')
        self.gpio_fds[gpio] = fd

    def _check_open(self, gpio):
        if gpio not in self.gpio_fds:
            self._open(gpio)



    def input(self, gpio):
        self._check_open(gpio)

        self.gpio_fds[gpio].seek(0)
        val= self.gpio_fds[gpio].read().strip()
        return False if val == '0' else True

    def request_gpio_interrupt(self, gpio, edge):
        val = open('/sys/class/gpio/gpio%d/edge' % gpio, 'wt').write("%s\n" % edge)
        self._check_open(gpio)

    def add_event_detect(self, gpio, edge, callback):
        self.request_gpio_interrupt(gpio, edge)

        already_present = (gpio in self.event_callbacks)
        self.event_callbacks[gpio] = callback
        if not already_present:
            self.gpio_first_event_fired[gpio] = False
            self.epoll.register(self.gpio_fds[gpio], select.EPOLLIN | select.EPOLLET)

    def remove_event_detect(self, gpio):
        self.request_gpio_interrupt(gpio, self.NONE)
        ret = self.event_callbacks.pop(gpio, None)

        if ret is not None:
            self.epoll.unregister(self.gpio_fds[gpio])


    def wait_for_edge(self, gpio, edge, timeout=None):
        if timeout == None:
            timeout = 1E100

        event = threading.Event()
        event.clear()
        callback = lambda x: event.set()

        self.add_event_detect(gpio, edge, callback)
        #~ print "wait for edge..."
        ret = event.wait(timeout)
        #~ print "wait for edge done"
        self.remove_event_detect(gpio)

        return ret


    #~ self.irq_gpio, GPIO.RISING, callback=self.interruptHandler)
GPIO = GPIOHandler()


