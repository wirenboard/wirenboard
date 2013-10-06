== libnfc-1.7.0 backport to debian stable ==

1) chroot to Debian stable armel distribution (copy your rootfs for instance)

2)  Install dev packages
apt-get install devscripts


3) do
dget -u -x http://ftp.de.debian.org/debian/pool/main/libn/libnfc/libnfc_1.7.0-2.dsc

then cd to libnfc-1.7.0

4) install dependencies

apt-get install debhelper dh-autoreconf libtool pkg-config libusb-dev

5) create packages

fakeroot debian/rules binary
