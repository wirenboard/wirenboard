# Wiren Board Zero rev 5.8+
export FORCE_WB_VERSION=58

board_include soc_imx28.sh

board_install() {
	chr_apt dropbear mmc-utils rsync
	set_fdt imx28-wirenboard58
}
