export FORCE_WB_VERSION=28

board_include soc_imx23.sh

board_install() {
	set_fdt imx23-wirenboard-ac-e1
}
