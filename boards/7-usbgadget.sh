# Wiren Board 7.2 and newer
export FORCE_WB_VERSION=72
export DTB=/boot/dtbs/sun8i-r40-wirenboard72x-initram.dtb

board_include soc_sun8i_r40.sh

board_install() {
    chr_apt dropbear mmc-utils rsync dosfstools util-linux openssl libateccssl1.1

	set_fdt sun8i-r40-wirenboard72x-initram
}
