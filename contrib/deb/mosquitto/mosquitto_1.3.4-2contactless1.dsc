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
 9e7d1d43a64dbde41047cd4e9ac8b498913c3c14 24888 mosquitto_1.3.4-2contactless1.debian.tar.gz
Checksums-Sha256: 
 0a3982d6b875a458909c8828731da04772035468700fa7eb2f0885f4bd6d0dbc 351761 mosquitto_1.3.4.orig.tar.gz
 8c086896f5c1158b11de878eda9105b422579f713cfd521fbdd59eb40cd18485 24888 mosquitto_1.3.4-2contactless1.debian.tar.gz
Files: 
 9d729849efd74c6e3eee17a4a002e1e9 351761 mosquitto_1.3.4.orig.tar.gz
 aa6526e39856e03cea04cd1630c2f827 24888 mosquitto_1.3.4-2contactless1.debian.tar.gz

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.12 (GNU/Linux)

iQEcBAEBAgAGBQJUIDYVAAoJEOSwlJ+u4Hhp1d0H/iIH4p5yni0qxiV5UcRsAgqS
P7Wci/fzhmqjLNrraTC5Z1ut3b2TBM9oexTReRUVEZnMDHTXvlJC4ukmtrzyTmJJ
LslzyFFbG66FTiMRIfj8yJ510uM6Jr4sy3dtSZH/RA0wr7GTz0hL4rzKtmrPDIEK
2P1zKmcLC/rHkRG/jXGkwiuETJg2fBYov+5dcz1hivoG8PTnLqICk9KQEeibBtUY
9/iUB0okILkHdm4t71BtHAeyVxJCzp+oPexEdSRA7Mk/P3lunpR+x6+F+JjIGYr2
L8r4vgboQjGvMga+p2G1myy75ptcn0YhtdFokYfoGT0DyDxegVfyOp524NYCcC4=
=sWpI
-----END PGP SIGNATURE-----
