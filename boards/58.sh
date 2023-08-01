# Wiren Board 5.8
export FORCE_WB_VERSION=58
export DTB=/boot/dtbs/imx28-wirenboard58.dtb

board_include soc_imx28.sh

board_install() {
	wb-common
	set_fdt imx28-wirenboard58
}
