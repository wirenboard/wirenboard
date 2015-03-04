BIN_ARMEL=WSS_static_armel
BIN_X86=WSS_linux_x86
BIN_DEST=WSS_static


.PHONY: all clean

all:
clean :

install: all
ifeq ($(DEB_HOST_ARCH),armel)
	install -m 0755 $(BIN_ARMEL) $(DESTDIR)/usr/bin/$(BIN_DEST)
else
ifeq ($(DEB_HOST_ARCH),amd64)
	install -m 0755 $(BIN_X86) $(DESTDIR)/usr/bin/$(BIN_DEST)
else
ifeq ($(DEB_HOST_ARCH),i386)
	install -m 0755 $(BIN_X86) $(DESTDIR)/usr/bin/$(BIN_DEST)
else
	$(error Unsupported arch)
endif
endif
endif


	install -m 0755 mqtt-wss $(DESTDIR)/etc/init.d/mqtt-wss

