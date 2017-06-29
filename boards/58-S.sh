# Wiren Board 5.8
export FORCE_WB_VERSION=58

board_include board_S.sh
board_include soc_imx28.sh

board_install() {
    install_wb5_s_packages

	rm -f ${OUTPUT}/etc/network/interfaces.wb-orig
	chr_apt ${S_NAME}-config

	set_fdt imx28-wirenboard58

	JSON=${OUTPUT}/etc/wb-hardware.conf
	json_edit '.slots|=map(if .id=="wb5-eth" then .module="" else . end)'
}