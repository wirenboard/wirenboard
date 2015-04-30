defineVirtualDevice("network", {
    title:"Network",
    cells: {
        "Ethernet IP": {
            type: "text",
            value: ""
        },
        "Wi-Fi IP": {
            type: "text",
            value: false
        },
        "PPP IP": {
            type: "text",
            value: ""
        }
    }
});



function _system_update_ip(name, iface) {
   runShellCommand('ip addr show ' + iface + ' | grep "inet " | cut -c 10- | cut -d/ -f1',{
      captureOutput: true,
      exitCallback: function (exitCode, capturedOutput) {
        if (capturedOutput.slice(0, 6) != "Device" ) {
            dev.network[name] = capturedOutput.slice(0,-1);
        } else {
            dev.network[name] = "";
        }
      }
  });
};


function _system_update_ip_all() {
    _system_update_ip("Ethernet IP", "eth0");
    _system_update_ip("Wi-Fi IP", "wlan0");
    _system_update_ip("PPP IP", "ppp0");
};

_system_update_ip_all();
setInterval(_system_update_ip_all, 60000);
