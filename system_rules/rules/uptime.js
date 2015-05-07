defineVirtualDevice("uptime", {
    title:"Uptime",
    cells: {
        "Current uptime": {
            type: "text",
            value: "0"
        }
    }
});


function _system_update_uptime() {
   runShellCommand('awk \'{print int($1/86400)\"d \"int(($1%86400)/3600)\"h \"int(($1%3600)/60)\"m\"}\' /proc/uptime',{
      captureOutput: true,
      exitCallback: function (exitCode, capturedOutput) {
	dev.uptime["Current uptime"] = capturedOutput;
      }
  });
};


_system_update_uptime();
setInterval(_system_update_uptime, 60000);
