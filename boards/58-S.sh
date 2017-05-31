# Wiren Board 5.8
export FORCE_WB_VERSION=58

S_NAME=`echo -e "\\x73\\x65\\x6d\\x33\\x36\\x35"`

board_include soc_imx28.sh

board_install() {
    chr_apt wb-mqtt-homeui wb-mqtt-serial wb-homa-w1 wb-homa-gpio \
    wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils \
    wb-test-suite wb-hwconf-manager wb-mqtt-dac

	rm -f ${OUTPUT}/etc/network/interfaces.wb-orig
	chr_apt ${S_NAME}-config

	set_fdt imx28-wirenboard58

	JSON=${OUTPUT}/etc/wb-hardware.conf
	json_edit '.slots|=map(if .id=="wb5-eth" then .module="" else . end)'
}

board_override_repos() {
	echo "deb http://release.${S_NAME}.ru/ ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/01-${S_NAME}.list
	wget http://release.${S_NAME}.ru/key${S_NAME} -O- | chr apt-key add -
}
