-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

Format: 3.0 (quilt)
Source: mosquitto
Binary: mosquitto, libmosquitto1, libmosquitto-dev, libmosquittopp1, libmosquittopp-dev, mosquitto-clients, python-mosquitto, python3-mosquitto, mosquitto-dbg
Architecture: any all
Version: 1.3.4-2contactless1
Maintainer: Roger A. Light <roger@atchoo.org>
Homepage: http://mosquitto.org/
Standards-Version: 3.9.5
Vcs-Browser: http://bitbucket.org/oojah/mosquitto-packaging/src
Vcs-Hg: http://bitbucket.org/oojah/mosquitto-packaging
Build-Depends: debhelper (>= 9), libc-ares-dev, libssl-dev (>= 1.0.0), libwrap0-dev, python-all (>= 2.6.6-3~), python3-all, uthash-dev, uuid-dev
Package-List: 
 libmosquitto-dev deb libdevel optional
 libmosquitto1 deb libs optional
 libmosquittopp-dev deb libdevel optional
 libmosquittopp1 deb libs optional
 mosquitto deb net optional
 mosquitto-clients deb net optional
 mosquitto-dbg deb debug extra
 python-mosquitto deb python optional
 python3-mosquitto deb python optional
Checksums-Sha1: 
 b818672cc0db723995d7c3201ef6962931dd891a 351761 mosquitto_1.3.4.orig.tar.gz
 fcd04a65683aab7515df5ff73355056981024f28 24566 mosquitto_1.3.4-2contactless1.debian.tar.gz
Checksums-Sha256: 
 0a3982d6b875a458909c8828731da04772035468700fa7eb2f0885f4bd6d0dbc 351761 mosquitto_1.3.4.orig.tar.gz
 a970402c8420475f63dd2cc9c5edb4109a4c097166b0b4a99c9fad6169249737 24566 mosquitto_1.3.4-2contactless1.debian.tar.gz
Files: 
 9d729849efd74c6e3eee17a4a002e1e9 351761 mosquitto_1.3.4.orig.tar.gz
 fafc72fc4fb218bb2e4dbabbd32968d1 24566 mosquitto_1.3.4-2contactless1.debian.tar.gz

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.12 (GNU/Linux)

iQEcBAEBAgAGBQJVOktlAAoJEOSwlJ+u4HhpdaIH/A8kybw44GhsJbrdaYU+A/Fc
4B67JeHOxiGG+haQqTTB6UKzk7WxvhjyTSPQOyHMTOH46zgI4uAZcF4brzOMt0A+
64bKRSeJaAD5luX1Nmi4DWFPo6Cm7cqpUJzD34pc3iiw55MtknYWdjD9FJCkxtwo
wzKQxMyXr+USpnh670iw9s+dBMOHbzxVK99Iaz0jHlTufke6Q4BDKezLN0EnmJpg
adPkvps2vcCTCpPDHBAO0UOXLCu8fx2Isop8+TB73TH8Zp7gq7i5HnEFMcWnvBUA
Y0XwNIB4jurxm2FAUzlsAWVVPcOnQpECDyj9HLj8ZvBZvEW/yDLgssS/a/45JOw=
=jpU7
-----END PGP SIGNATURE-----
