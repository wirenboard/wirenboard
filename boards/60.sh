# Wiren Board 6.0 (pre-production)
export FORCE_WB_VERSION=60

board_include soc_imx6ul.sh

board_install() {
	install_wb5_packages

	set_fdt imx6ul-wirenboard-evk
}
