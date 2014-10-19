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
 4592f6eaee6d3c2cb5153c64fad542435057d8e3 24813 mosquitto_1.3.4-2.debian.tar.gz
Checksums-Sha256: 
 0a3982d6b875a458909c8828731da04772035468700fa7eb2f0885f4bd6d0dbc 351761 mosquitto_1.3.4.orig.tar.gz
 093b41e3f6e9674a7b7d4015bcf4d6e01285bb4e66991504b674f38658d48f6a 24813 mosquitto_1.3.4-2.debian.tar.gz
Files: 
 9d729849efd74c6e3eee17a4a002e1e9 351761 mosquitto_1.3.4.orig.tar.gz
 e6c25f7a812f838e1bf0b5b14c2b13c8 24813 mosquitto_1.3.4-2.debian.tar.gz
