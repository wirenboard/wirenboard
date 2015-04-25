U-boot bootlets
See http://eewiki.net/display/linuxonarm/iMX233-OLinuXino

Example:
sudo dd if=../contrib/u-boot/u-boot.sb of=/dev/sdc1 bs=512 seek=4

u-boot.sb.wb4_hynix: CL=2.5 133MHz
u-boot.sb.wb4_alliance : CL=2.5 133MHz LOWPRR=1