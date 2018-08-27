export FORCE_WB_VERSION=28

board_include soc_imx23.sh

board_install() {
	chr_apt wb-mqtt-homeui libnfc5 libnfc-bin libnfc-examples libnfc-pn53x-examples
	set_fdt imx23-wirenboard28
}
