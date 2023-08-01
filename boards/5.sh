# Wiren Board 5
export FORCE_WB_VERSION=52
export DTB=/boot/dtbs/imx28-wirenboard52.dtb

board_include soc_imx28.sh
BOARD_PACKAGES+=( wb-mqtt-lirc )

board_install() {
	wb-common
	set_fdt imx28-wirenboard52
}
