BIN=WSS_static_armel

.PHONY: all clean

all:
clean :

install: all
	install -m 0755 $(BIN) $(DESTDIR)/usr/bin/$(BIN)
	install -m 0755 mqtt-wss $(DESTDIR)/etc/init.d/mqtt-wss

