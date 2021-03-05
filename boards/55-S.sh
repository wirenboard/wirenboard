# Wiren Board 5.5
export FORCE_WB_VERSION=55
export DTB=/boot/dtbs/imx28-wirenboard55.dtb

board_include board_S.sh
board_include soc_imx28.sh

board_install() {
    chr_apt wb-mqtt-homeui wb-mqtt-serial wb-homa-w1 wb-homa-gpio \
    wb-homa-adc wb-rules wb-rules-system netplug hostapd bluez can-utils \
    wb-test-suite wb-hwconf-manager wb-mqtt-dac

    rm -f ${OUTPUT}/etc/network/interfaces.wb-orig
    chr_apt ${S_NAME}-config

    set_fdt imx28-wirenboard55
}