LIB_LOCATION=/usr/lib/wb-test-suite
.PHONY: all clean

all:
clean :

install: all
	mkdir -p $(DESTDIR)/$(LIB_LOCATION)/wb5_func_test
	mkdir -p $(DESTDIR)/$(LIB_LOCATION)/hw_test_common

	install -m 0644 wb5_func_test/*.py  $(DESTDIR)/$(LIB_LOCATION)/wb5_func_test
	install -m 0644 hw_test_common/*.py  $(DESTDIR)/$(LIB_LOCATION)/hw_test_common

