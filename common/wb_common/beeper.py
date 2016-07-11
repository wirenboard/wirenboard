import os
import time

class Beeper(object):
    def __init__(self, pwm_num):
        self.pwm_num = pwm_num
        self.pwm_dir = '/sys/class/pwm/pwmchip0/pwm' + str(pwm_num)

    def setup(self):
        if not os.path.exists(self.pwm_dir):
            open('/sys/class/pwm/pwmchip0/export', 'w').write(str(self.pwm_num) + '\n')


        open(self.pwm_dir + '/enable', 'w').write('0\n')
        open(self.pwm_dir + '/period', 'w').write('250000\n')
        open(self.pwm_dir + '/duty_cycle', 'w').write('125000\n')


    def set(self, enabled):
        open(self.pwm_dir + '/enable', 'w').write(('1' if enabled else '0') + '\n')

    def beep(self, duration, repeat=1):
        for i in xrange(repeat):
            if i != 0:
                time.sleep(duration)
            self.set(1)
            time.sleep(duration)
            self.set(0)

    def test(self):
        try:
            self.beep(0.1, 3)
        finally:
            self.set(False)



_beeper = Beeper(2)

setup = _beeper.setup
test = _beeper.test
