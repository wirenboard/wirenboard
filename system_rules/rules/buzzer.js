(function() {
  defineVirtualDevice("buzzer", {
    title: "Buzzer", //

    cells: {
      frequency : {
          type : "range",
          value : 3000,
          max : 7000,
      },
      volume : {
          type : "range",
          value : 10,
          max : 100,
      },
      enabled : {
          type : "switch",
          value : false,
      },
    }
  });

  var pwm_number = 2;

  runShellCommand(". /etc/wb_env.sh && echo -n $WB_PWM_BUZZER", {
    captureOutput: true,
    exitCallback: function (exitCode, capturedOutput) {
      if (capturedOutput) {
        pwm_number = parseInt(capturedOutput);
      }
      
      runShellCommand("echo " + pwm_number + "  > /sys/class/pwm/pwmchip0/export");
    }
  });
  

  function _buzzer_set_params() {
    var period = parseInt(1.0 / dev.buzzer.frequency * 1E9);
    var duty_cycle = parseInt(dev.buzzer.volume  * 1.0  / 100 * period * 0.5);
    
    runShellCommand("echo " + period + " > /sys/class/pwm/pwmchip0/pwm" + pwm_number + "/period");
    runShellCommand("echo " + duty_cycle + " > /sys/class/pwm/pwmchip0/pwm"+ pwm_number + "/duty_cycle");
  };

  defineRule("_system_buzzer_params", {
    whenChanged: [
      "buzzer/frequency",
      "buzzer/volume",
      ],

    then: function (newValue, devName, cellName) {
      if ( dev.buzzer.enabled) {
          _buzzer_set_params();
      }
    }
  });

  defineRule("_system_buzzer_onof", {
    whenChanged: "buzzer/enabled",
    then: function (newValue, devName, cellName) {
      if ( dev.buzzer.enabled) {
          _buzzer_set_params();
          runShellCommand("echo 1  > /sys/class/pwm/pwmchip0/pwm" + pwm_number + "/enable");
      } else {
          runShellCommand("echo 0  > /sys/class/pwm/pwmchip0/pwm" + pwm_number + "/enable");
      }
     }
  });
})();