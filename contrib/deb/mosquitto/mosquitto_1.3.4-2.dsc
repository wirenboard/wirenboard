-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

Format: 3.0 (quilt)
Source: mosquitto
Binary: mosquitto, libmosquitto1, libmosquitto-dev, libmosquittopp1, libmosquittopp-dev, mosquitto-clients, python-mosquitto, python3-mosquitto, mosquitto-dbg
Architecture: any all
Version: 1.3.4-2
Maintainer: Roger A. Light <roger@atchoo.org>
Homepage: http://mosquitto.org/
Standards-Version: 3.9.5
Vcs-Browser: http://bitbucket.org/oojah/mosquitto-packaging/src
Vcs-Hg: http://bitbucket.org/oojah/mosquitto-packaging
Build-Depends: debhelper (>= 9), libc-ares-dev, libssl-dev (>= 1.0.0), libwrap0-dev, python-all (>= 2.6.6-3~), python3-all, uthash-dev, uuid-dev
Package-List:
 libmosquitto-dev deb libdevel optional arch=all
 libmosquitto1 deb libs optional arch=any
 libmosquittopp-dev deb libdevel optional arch=all
 libmosquittopp1 deb libs optional arch=any
 mosquitto deb net optional arch=any
 mosquitto-clients deb net optional arch=any
 mosquitto-dbg deb debug extra arch=any
 python-mosquitto deb python optional arch=all
 python3-mosquitto deb python optional arch=all
Checksums-Sha1:
 b818672cc0db723995d7c3201ef6962931dd891a 351761 mosquitto_1.3.4.orig.tar.gz
 da34c4300a858916c672c256f8f076fd14c540a2 20248 mosquitto_1.3.4-2.debian.tar.xz
Checksums-Sha256:
 0a3982d6b875a458909c8828731da04772035468700fa7eb2f0885f4bd6d0dbc 351761 mosquitto_1.3.4.orig.tar.gz
 75fb3884b62bdf5d7a7b8c844d483e563fda9702c9928b3ea9018433233f8995 20248 mosquitto_1.3.4-2.debian.tar.xz
Files:
 9d729849efd74c6e3eee17a4a002e1e9 351761 mosquitto_1.3.4.orig.tar.gz
 b18d5d76355405c95ced90c37616902e 20248 mosquitto_1.3.4-2.debian.tar.xz

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1

iQIcBAEBAgAGBQJT8B85AAoJEN5juccE6+nv54AP/AlcXbyewsKRMwFdm+z8m187
OCxd1sQpVccYcIB+Td1nD45cg51jilWQNX/NDZ1qS9wJRsJ2TXY/xd7610ZcoFVh
hipa2P8YPovT9BR58bBlibHAYAJcXEotelLxWDdPzK3hKSOup3dqRZEResEbvfTf
vKmVcZKD/3FU/6aJyLLEo4lGjHqseMyhG/JOuw1Os1GGH+tyiwRgTkmYUTOUPf/j
/F+1rFnAvb5fs43p9E0LBd4DhHGsEcKMqqVLa43k6gdUkQouComna0CVKOXCGbOR
a7fBaE3p5aCD1VSazlmfusTDO+s4rl1MIGFVDVFLdcVrrveIj80D1Oi7i4vN+z48
ja1vKbMctXr1BI9/Ry5O/022ZmZsYj1hOylPBzG7ZodXhHB3RUKVUyCRysEQVK6p
Q468Nm+IOYvHqdwZrHC45qMcL0vaeFKu/XBQsxPJr0qmK4VDcIegg7n/tQrO/JJ+
SGtuFA+a41LL8L4A1gSJZvIuOjBfQKJB3hj+iOFfwbX4UWAzz7k12dxCxBMcn6P+
Hwo/t5O7xJA/RF/hr/e4K6kKWSFbpoS9mDYYNiloWuXabCFDNNbKHcyyU2sCy+cd
t68ZsEo23kScwIpsagr5wLV6CLCpqbsUU9snzdpISO+3l7uBoarUnYgdfHmw/jt1
BfFNWDxC0JV6YvNPRFN5
=tE7r
-----END PGP SIGNATURE-----
