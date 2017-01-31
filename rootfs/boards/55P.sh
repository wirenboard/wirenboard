# Wiren Board 5 for Proton
export FORCE_WB_VERSION=55

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-rules wb-rules-system netplug hostapd can-utils wb-test-suite wb-hwconf-manager wb-mqtt-dac

	set_fdt imx28-wirenboard55

	JSON=${OUTPUT}/etc/wb-hardware.conf
	json_edit '.slots|=map(if .id=="wb55-mod1" then .module="wbe-do-r6c-1" else . end)'
	json_edit '.slots|=map(if .id=="wb55-mod2" then .module="wbe-do-r6c-1" else . end)'
	json_edit '.slots|=map(if .id=="wb55-gsm" then .module="wb56-mod-rtc" else . end)'
}
