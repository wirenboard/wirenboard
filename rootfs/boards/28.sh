export FORCE_WB_VERSION=28

. ${SCRIPT_DIR}/boards/include/soc_imx23.sh

board_install() {
	chr_apt wb-mqtt-homeui
	set_fdt imx23-wirenboard28
}
