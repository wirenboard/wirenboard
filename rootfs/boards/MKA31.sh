# MKA31 based on WB52 (netmon2-1)
export FORCE_WB_VERSION=52

board_install() {
	chr_apt wb-mqtt-homeui wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils wb-test-suite wb-hwconf-manager wb-mqtt-am2320 zabbix-agent

	cp ${SCRIPT_DIR}/../../wb-dbic/set_confidential.sh ${OUTPUT}/
	chr /set_confidential.sh
	rm ${OUTPUT}/set_confidential.sh

	set_fdt imx28-wirenboard52
}
