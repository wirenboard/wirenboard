# CQC10 device
export FORCE_WB_VERSION=CQC10

board_install() {
	chr_apt wb-homa-w1 wb-homa-gpio wb-mqtt-spl-meter zabbix-agent wb-mqtt-homeui-mediamain

	echo "Add wb-mqtt-tcs34725 package"
	chr_install_deb /home/boger/work/board/cinema/wb-mqtt-tcs34725_1.1_all.deb
	echo "Add wb-techneva package"
	chr_install_deb /home/boger/work/board/cinema/wb-techneva/wb-techneva-cqc_1.1_all.deb

	set_fdt imx23-wirenboard-cqc10
}
