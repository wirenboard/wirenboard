# Wiren Board 5
export FORCE_WB_VERSION=55
export DTB=/boot/dtbs/imx28-wirenboard55.dtb

board_include soc_imx28.sh

board_install() {
	wb-common
	set_fdt imx28-wirenboard55
}
