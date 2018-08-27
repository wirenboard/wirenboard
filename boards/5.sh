# Wiren Board 5
export FORCE_WB_VERSION=52

board_include soc_imx28.sh
BOARD_PACKAGES+=( wb-mqtt-lirc )

board_install() {
	install_wb5_packages
	set_fdt imx28-wirenboard52
}
