S_NAME=`echo -e "\\x73\\x65\\x6d\\x33\\x36\\x35"`

board_override_repos() {
    echo "deb http://release.${S_NAME}.ru/ ${RELEASE} main" > ${OUTPUT}/etc/apt/sources.list.d/01-${S_NAME}.list
    wget http://release.${S_NAME}.ru/key${S_NAME} -O- | chr apt-key add -
}

install_wb5_s_packages() {
    chr_apt wb-mqtt-homeui wb-mqtt-serial wb-homa-w1 wb-homa-gpio \
        wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils \
        wb-test-suite wb-hwconf-manager wb-mqtt-dac
}
