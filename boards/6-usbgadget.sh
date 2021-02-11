# Wiren Board 6.1
export FORCE_WB_VERSION=61

board_include soc_imx6ul.sh

board_install() {
	chr_apt dropbear mmc-utils rsync

	set_fdt imx6ul-wirenboard61
}
