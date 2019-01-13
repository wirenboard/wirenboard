# Wiren Board 6.1 and newer
export FORCE_WB_VERSION=
export DTB=/boot/dtbs/imx6ul-wirenboard61.dtb

board_include soc_imx6ul.sh

board_install() {
	install_wb5_packages

	set_fdt imx6ul-wirenboard61

	# FIXME: armhf busybox-syslogd don't supports -s option, so here is a temporary kludge
	sed -r -i 's/(SYSLOG_OPTS=).*/\1""/' $OUTPUT/etc/default/busybox-syslogd
}
