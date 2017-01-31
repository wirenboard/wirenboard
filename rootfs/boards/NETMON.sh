# NETMON-1
export FORCE_WB_VERSION=KMON1

. ${SCRIPT_DIR}/boards/include/soc_imx23.sh

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent wb-mqtt-serial wb-rules

	chr_apt netplug

	set_fdt imx23-wirenboard-kmon1
}
