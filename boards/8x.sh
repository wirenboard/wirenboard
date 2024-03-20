# Wiren Board 8.0 and newer
export FORCE_WB_VERSION=
export DTB=/boot/dtbs/sun50i-h616-wirenboard8xx.dtb

board_include soc_sun50i_h616.sh

board_install() {
	wb-common_install

	set_fdt sun50i-h616-wirenboard8xx
}
