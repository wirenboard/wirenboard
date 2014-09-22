# =============================================================================
# User configuration section.
#
# Largely, these are options that are designed to make mosquitto run more
# easily in restrictive environments by removing features.
#
# Modify the variable below to enable/disable features.
#
# Can also be overriden at the command line, e.g.:
#
# make WITH_TLS=no
# =============================================================================

# Uncomment to compile the broker with tcpd/libwrap support.
#WITH_WRAP:=yes

# Comment out to disable SSL/TLS support in the broker and client.
# Disabling this will also mean that passwords must be stored in plain text. It
# is strongly recommended that you only disable WITH_TLS if you are not using
# password authentication at all.
WITH_TLS:=yes

# Comment out to disable TLS/PSK support in the broker and client. Requires
# WITH_TLS=yes.
# This must be disabled if using openssl < 1.0.
WITH_TLS_PSK:=yes

# Comment out to disable client client threading support.
WITH_THREADING:=yes

# Uncomment to compile the broker with strict protocol support. This means that
# both the client library and the broker will be very strict about protocol
# compliance on incoming data. Neither of them will return an error on
# incorrect "remaining length" values if this is commented out. The old
# behaviour (prior to 0.12) is equivalent to compiling with
# WITH_STRICT_PROTOCOL defined and means that clients will be immediately
# disconnected from the broker on non-compliance.
#WITH_STRICT_PROTOCOL:=yes

# Comment out to remove bridge support from the broker. This allow the broker
# to connect to other brokers and subscribe/publish to topics. You probably
# want to leave this included unless you want to save a very small amount of
# memory size and CPU time.
WITH_BRIDGE:=yes

# Comment out to remove persistent database support from the broker. This
# allows the broker to store retained messages and durable subscriptions to a
# file periodically and on shutdown. This is usually desirable (and is
# suggested by the MQTT spec), but it can be disabled if required.
WITH_PERSISTENCE:=yes

# Comment out to remove memory tracking support from the broker. If disabled,
# mosquitto won't track heap memory usage nor export '$SYS/broker/heap/current
# size', but will use slightly less memory and CPU time.
WITH_MEMORY_TRACKING:=yes

# Compile with database upgrading support? If disabled, mosquitto won't
# automatically upgrade old database versions.
# Not currently supported.
#WITH_DB_UPGRADE:=yes

# Comment out to remove publishing of the $SYS topic hierarchy containing
# information about the broker state.
WITH_SYS_TREE:=yes

# Build with Python module. Comment out if Python is not installed, or required
# Python modules are not available.
WITH_PYTHON:=yes

# Build with SRV lookup support.
WITH_SRV:=yes

# =============================================================================
# End of user configuration
# =============================================================================


# Also bump lib/mosquitto.h, lib/python/setup.py, CMakeLists.txt,
# installer/mosquitto.nsi, installer/mosquitto-cygwin.nsi
VERSION=1.3.4
TIMESTAMP:=$(shell date "+%F %T%z")

# Client library SO version. Bump if incompatible API/ABI changes are made.
SOVERSION=1

# Man page generation requires xsltproc and docbook-xsl
XSLTPROC=xsltproc
# For html generation
DB_HTML_XSL=man/html.xsl

#MANCOUNTRIES=en_GB

UNAME:=$(shell uname -s)
ifeq ($(UNAME),SunOS)
	ifeq ($(CC),cc)
		CFLAGS?=-O
	else
		CFLAGS?=-Wall -ggdb -O2
	endif
else
	CFLAGS?=-Wall -ggdb -O2
endif

LIB_CFLAGS:=${CFLAGS} ${CPPFLAGS} -I. -I.. -I../lib
LIB_CXXFLAGS:=$(LIB_CFLAGS) ${CPPFLAGS}
LIB_LDFLAGS:=${LDFLAGS}

BROKER_CFLAGS:=${LIB_CFLAGS} ${CPPFLAGS} -DVERSION="\"${VERSION}\"" -DTIMESTAMP="\"${TIMESTAMP}\"" -DWITH_BROKER
CLIENT_CFLAGS:=${CFLAGS} ${CPPFLAGS} -I../lib -DVERSION="\"${VERSION}\""

ifeq ($(UNAME),FreeBSD)
	BROKER_LIBS:=-lm
else
	BROKER_LIBS:=-ldl -lm
endif
LIB_LIBS:=
PASSWD_LIBS:=

ifeq ($(UNAME),Linux)
	BROKER_LIBS:=$(BROKER_LIBS) -lrt
	LIB_LIBS:=$(LIB_LIBS) -lrt
endif

CLIENT_LDFLAGS:=$(LDFLAGS) -L../lib ../lib/libmosquitto.so.${SOVERSION}

ifeq ($(UNAME),SunOS)
	ifeq ($(CC),cc)
		LIB_CFLAGS:=$(LIB_CFLAGS) -xc99 -KPIC
	else
		LIB_CFLAGS:=$(LIB_CFLAGS) -fPIC
	endif

	ifeq ($(CXX),CC)
		LIB_CXXFLAGS:=$(LIB_CXXFLAGS) -KPIC
	else
		LIB_CXXFLAGS:=$(LIB_CXXFLAGS) -fPIC
	endif
else
	LIB_CFLAGS:=$(LIB_CFLAGS) -fPIC
	LIB_CXXFLAGS:=$(LIB_CXXFLAGS) -fPIC
endif

ifneq ($(UNAME),SunOS)
	LIB_LDFLAGS:=$(LIB_LDFLAGS) -Wl,--version-script=linker.version -Wl,-soname,libmosquitto.so.$(SOVERSION)
endif

ifeq ($(UNAME),QNX)
	BROKER_LIBS:=$(BROKER_LIBS) -lsocket
	LIB_LIBS:=$(LIB_LIBS) -lsocket
endif

ifeq ($(WITH_WRAP),yes)
	BROKER_LIBS:=$(BROKER_LIBS) -lwrap
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_WRAP
endif

ifeq ($(WITH_TLS),yes)
	BROKER_LIBS:=$(BROKER_LIBS) -lssl -lcrypto
	LIB_LIBS:=$(LIB_LIBS) -lssl -lcrypto
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_TLS
	LIB_CFLAGS:=$(LIB_CFLAGS) -DWITH_TLS
	PASSWD_LIBS:=-lcrypto
	CLIENT_CFLAGS:=$(CLIENT_CFLAGS) -DWITH_TLS

	ifeq ($(WITH_TLS_PSK),yes)
		BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_TLS_PSK
		LIB_CFLAGS:=$(LIB_CFLAGS) -DWITH_TLS_PSK
		CLIENT_CFLAGS:=$(CLIENT_CFLAGS) -DWITH_TLS_PSK
	endif
endif

ifeq ($(WITH_THREADING),yes)
	LIB_LIBS:=$(LIB_LIBS) -lpthread
	LIB_CFLAGS:=$(LIB_CFLAGS) -DWITH_THREADING
endif

ifeq ($(WITH_STRICT_PROTOCOL),yes)
	LIB_CFLAGS:=$(LIB_CFLAGS) -DWITH_STRICT_PROTOCOL
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_STRICT_PROTOCOL
endif

ifeq ($(WITH_BRIDGE),yes)
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_BRIDGE
endif

ifeq ($(WITH_PERSISTENCE),yes)
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_PERSISTENCE
endif

ifeq ($(WITH_MEMORY_TRACKING),yes)
	ifneq ($(UNAME),SunOS)
		BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_MEMORY_TRACKING
	endif
endif

#ifeq ($(WITH_DB_UPGRADE),yes)
#	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_DB_UPGRADE
#endif

ifeq ($(WITH_SYS_TREE),yes)
	BROKER_CFLAGS:=$(BROKER_CFLAGS) -DWITH_SYS_TREE
endif

ifeq ($(WITH_SRV),yes)
	LIB_CFLAGS:=$(LIB_CFLAGS) -DWITH_SRV
	LIB_LIBS:=$(LIB_LIBS) -lcares
endif

ifeq ($(UNAME),SunOS)
	BROKER_LIBS:=$(BROKER_LIBS) -lsocket -lnsl
	LIB_LIBS:=$(LIB_LIBS) -lsocket -lnsl
endif


INSTALL?=install
prefix=/usr/local
mandir=${prefix}/share/man
localedir=${prefix}/share/locale
STRIP?=strip
