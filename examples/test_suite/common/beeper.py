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

    
    def test(self):
		try:
			for i in xrange(3):
				time.sleep( 0.1)
				open(self.pwm_dir + '/enable', 'w').write('1\n')
				time.sleep( 0.1)
				open(self.pwm_dir + '/enable', 'w').write('0\n')
		finally:
			open(self.pwm_dir + '/enable', 'w').write('0\n')



_beeper = Beeper(2)

setup = _beeper.setup
test = _beeper.test
