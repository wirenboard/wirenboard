export FORCE_WB_VERSION=28

board_install() {
	chr_apt wb-mqtt-homeui
	set_fdt imx23-wirenboard28
}
