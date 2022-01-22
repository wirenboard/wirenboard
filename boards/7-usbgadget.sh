# Wiren Board 7.2 and newer
export FORCE_WB_VERSION=72
export DTB=/boot/dtbs/sun8i-r40-wirenboard720.dtb

board_include soc_sun8i_r40.sh

board_install() {
    chr_apt dropbear mmc-utils rsync dosfstools

	set_fdt sun8i-r40-wirenboard720
}