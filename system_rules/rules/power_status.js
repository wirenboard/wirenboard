

defineVirtualDevice("power_status", {
  title: "Power status", //

  cells: {
    'working on battery' : {
        type : "switch",
        value : false,
        readonly : true
    },
    'Vin' : {
        type : "voltage",
        value : 0
    }


  }
});



defineRule("_system_track_vin", {
    whenChanged: "wb-adc/Vin",
    then: function() {
        if (dev["wb-adc"]["Vin"] < dev["wb-adc"]["BAT"] ) {
            dev["power_status"]["Vin"] = 0;
        } else {
            dev["power_status"]["Vin"] = dev["wb-adc"]["Vin"] ;
        }
    }
});



defineRule("_system_dc_on", {
  asSoonAs: function () {
    return  dev["wb-adc"]["Vin"] > dev["wb-adc"]["BAT"];
  },
  then: function () {
    dev["power_status"]["working on battery"] = false;
  }
});

defineRule("_system_dc_off", {
  asSoonAs: function () {
    return  dev["wb-adc"]["Vin"] <= dev["wb-adc"]["BAT"];
  },
  then: function () {
    dev["power_status"]["working on battery"] = true;
  }
});

