include ../../config.mk

ifneq ($(UNAME),SunOS)
	LIB_LDFLAGS:=$(LDFLAGS) -Wl,-soname,libmosquittopp.so.${SOVERSION}
endif

.PHONY : clean install

all : libmosquittopp.so.${SOVERSION}

install : all
	$(INSTALL) -d ${libdir}/
	$(INSTALL) libmosquittopp.so.${SOVERSION} ${libdir}/libmosquittopp.so.${SOVERSION}
	ln -sf libmosquittopp.so.${SOVERSION} ${libdir}/libmosquittopp.so
	$(INSTALL) -d ${DESTDIR}${prefix}/include/
	$(INSTALL) mosquittopp.h ${DESTDIR}${prefix}/include/mosquittopp.h
	
uninstall :
	-rm -f ${libdir}/libmosquittopp.so.${SOVERSION}
	-rm -f ${libdir}/libmosquittopp.so
	-rm -f ${DESTDIR}${prefix}/include/mosquittopp.h

clean :
	-rm -f *.o libmosquittopp.so.${SOVERSION}

libmosquittopp.so.${SOVERSION} : mosquittopp.o
	${CROSS_COMPILE}$(CXX) -shared $(LIB_LDFLAGS) $< -o $@ ../libmosquitto.so.${SOVERSION}

mosquittopp.o : mosquittopp.cpp mosquittopp.h
	${CROSS_COMPILE}$(CXX) $(LIB_CXXFLAGS) -c $< -o $@

