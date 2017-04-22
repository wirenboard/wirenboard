# MKA3
export FORCE_WB_VERSION=KMON1

board_include soc_imx23.sh

board_install() {
	chr_apt wb-mqtt-homeui wb-homa-gpio wb-homa-adc wb-homa-w1 wb-mqtt-sht1x zabbix-agent wb-dbic

	# https://github.com/contactless/wb-dbic
	cp ${SCRIPT_DIR}/../../wb-dbic/set_confidential.sh ${OUTPUT}/
	chr /set_confidential.sh
	rm ${OUTPUT}/set_confidential.sh

	set_fdt imx23-wirenboard-kmon1
}
