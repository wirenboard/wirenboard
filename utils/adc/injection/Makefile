DESTDIR=/
prefix=usr
BIN_NAME=lradc-set-current

ifeq ($(DEB_BUILD_GNU_TYPE),$(DEB_HOST_GNU_TYPE))
       CC=gcc
else
       CC=$(DEB_HOST_GNU_TYPE)-gcc
endif


$(BIN_NAME):
	$(CC) lradc_set_current.c imx233.c -o $(BIN_NAME)


install: $(BIN_NAME)
	install -m 0755 $(BIN_NAME) $(DESTDIR)/$(prefix)/bin/$(BIN_NAME)

clean:
	@rm -f $(BIN_NAME)
.PHONY: install clean all



