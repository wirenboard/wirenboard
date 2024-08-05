# Wiren Board 8.0 and newer
# DTB here is a bootlet-dtb (common with wb8x & wb85x)
# All hardware-dependent services build actual configs at runtime
# => common dtb here will not affect config-install-magic, while building rootfs
export FORCE_WB_VERSION=
export DTB=/boot/dtbs/allwinner/sun50i-h616-wirenboard8xx.dtb

board_include soc_sun50i_h616.sh

board_install() {
	wb-common_install

	set_fdt sun50i-h616-wirenboard8xx
}
