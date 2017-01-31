# WB Smart Home specific
export FORCE_WB_VERSION=32

. ${SCRIPT_DIR}/boards/include/soc_imx23.sh

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system

	chr_apt netplug hostapd

	set_fdt imx23-wirenboard32
}
