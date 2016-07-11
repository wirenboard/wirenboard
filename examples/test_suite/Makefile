LIB_LOCATION=/usr/lib/wb-test-suite
.PHONY: all clean

all:
clean :

install: all
	mkdir -p $(DESTDIR)/$(LIB_LOCATION)/common
	mkdir -p $(DESTDIR)/$(LIB_LOCATION)/wb5_func_test

	install -m 0644 wb5_func_test/*.py  $(DESTDIR)/$(LIB_LOCATION)/wb5_func_test

