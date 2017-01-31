# Wiren Board 6
export FORCE_WB_VERSION=60

. ${SCRIPT_DIR}/boards/include/soc_imx6ul.sh

board_install() {
	chr_apt wb-mqtt-homeui wb-rules wb-rules-system netplug wb-test-suite wb-hwconf-manager

	set_fdt imx6ul-wirenboard-evk
}
