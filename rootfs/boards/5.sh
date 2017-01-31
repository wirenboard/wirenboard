# Wiren Board 5
export FORCE_WB_VERSION=52

. ${SCRIPT_DIR}/boards/include/soc_imx28.sh

board_install() {
	install_wb5_packages
	set_fdt imx28-wirenboard52
}
