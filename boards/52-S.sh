# Wiren Board 5.5
export FORCE_WB_VERSION=52

board_include board_S.sh
board_include soc_imx28.sh

board_install() {
    install_wb5_s_packages

    rm -f ${OUTPUT}/etc/network/interfaces.wb-orig
    chr_apt ${S_NAME}-config

    set_fdt imx28-wirenboard52
}