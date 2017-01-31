# Wiren Board 4
export FORCE_WB_VERSION=41

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-ism-radio wb-mqtt-serial wb-homa-w1 wb-homa-gpio wb-homa-adc python-nrf24 wb-rules wb-rules-system netplug

	echo "Add rtl8188 hostapd package"

	RTL8188_DEB=hostapd_1.1-rtl8188_armel.deb
	chr_install_deb "${SCRIPT_DIR}/../contrib/rtl8188_hostapd/${RTL8188_DEB}"

	set_fdt imx23-wirenboard41
}
