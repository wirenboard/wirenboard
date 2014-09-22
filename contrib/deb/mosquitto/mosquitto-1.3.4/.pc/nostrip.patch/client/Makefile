include ../config.mk

.PHONY: all install uninstall reallyclean clean

all : mosquitto_pub mosquitto_sub

mosquitto_pub : pub_client.o ../lib/libmosquitto.so.${SOVERSION}
	${CC} $< -o $@ ${CLIENT_LDFLAGS}

mosquitto_sub : sub_client.o ../lib/libmosquitto.so.${SOVERSION}
	${CC} $< -o $@ ${CLIENT_LDFLAGS}

pub_client.o : pub_client.c ../lib/libmosquitto.so.${SOVERSION}
	${CC} -c $< -o $@ ${CLIENT_CFLAGS}

sub_client.o : sub_client.c ../lib/libmosquitto.so.${SOVERSION}
	${CC} -c $< -o $@ ${CLIENT_CFLAGS}

../lib/libmosquitto.so.${SOVERSION} :
	$(MAKE) -C ../lib

install : all
	$(INSTALL) -d ${DESTDIR}$(prefix)/bin
	$(INSTALL) -s --strip-program=$(STRIP) mosquitto_pub ${DESTDIR}${prefix}/bin/mosquitto_pub
	$(INSTALL) -s --strip-program=$(STRIP) mosquitto_sub ${DESTDIR}${prefix}/bin/mosquitto_sub

uninstall :
	-rm -f ${DESTDIR}${prefix}/bin/mosquitto_pub
	-rm -f ${DESTDIR}${prefix}/bin/mosquitto_sub

reallyclean : clean

clean : 
	-rm -f *.o mosquitto_pub mosquitto_sub
