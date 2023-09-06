# Wiren Board 6.7 and newer
export FORCE_WB_VERSION=
export DTB=/boot/dtbs/imx6ul-wirenboard670.dtb

board_include soc_imx6ul.sh

board_install() {
	wb-common_install

	set_fdt imx6ul-wirenboard670
}
