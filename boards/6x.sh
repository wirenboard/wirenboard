# Wiren Board 6.1 and newer
export FORCE_WB_VERSION=
export DTB=/boot/dtbs/imx6ul-wirenboard61.dtb

board_include soc_imx6ul.sh

board_install() {
	install_wb5_packages

	set_fdt imx6ul-wirenboard61
}
