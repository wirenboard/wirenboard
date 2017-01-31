# Wiren Board Zero rev 5.5+
export FORCE_WB_VERSION=55

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-adc wb-rules wb-rules-system netplug wb-test-suite wb-hwconf-manager

	set_fdt imx28-wirenboard55

	JSON=${OUTPUT}/etc/wb-hardware.conf
	json_edit '.slots|=map(select(.id !="wb55-mod1"))'
	json_edit '.slots|=map(select(.id !="wb55-mod2"))'

	for extio_n in {1..8}; do
		json_edit '.slots|=map(select(.id !="wb5-extio'${extio_n}'"))'
	done

	json_edit '.slots|=map(if .id=="wb55-gsm" then .module="wb56-mod-rtc" else . end)'
}
