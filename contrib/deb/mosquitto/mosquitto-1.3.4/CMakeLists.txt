# This is a cmake script.

set(CMAKE_LEGACY_CYGWIN_WIN32 0)

project(mosquitto)

cmake_minimum_required(VERSION 2.6)

set (VERSION 1.3.4)

if (WIN32)
	execute_process(COMMAND cmd /c echo %DATE% %TIME% OUTPUT_VARIABLE TIMESTAMP
			OUTPUT_STRIP_TRAILING_WHITESPACE)
else (WIN32)
	execute_process(COMMAND date "+%F %T%z" OUTPUT_VARIABLE TIMESTAMP
			OUTPUT_STRIP_TRAILING_WHITESPACE)
endif (WIN32)

add_definitions (-DCMAKE -DVERSION=\"${VERSION}\" -DTIMESTAMP=\"${TIMESTAMP}\")

if (WIN32)
	set (BINDIR .)
	set (SBINDIR .)
	set (SYSCONFDIR .)
	set (LIBDIR .)
	set (INCLUDEDIR include)
	set (DATAROOTDIR share)
	set (MANDIR man)
    set (SHAREDEST .)
    add_definitions("-D_CRT_SECURE_NO_WARNINGS")
else (WIN32)
	set (BINDIR bin)
	set (SBINDIR sbin)
	if (${CMAKE_INSTALL_PREFIX} STREQUAL /usr)
		set (SYSCONFDIR /etc/mosquitto)
	else (${CMAKE_INSTALL_PREFIX} STREQUAL /usr)
		set (SYSCONFDIR etc/mosquitto)
	endif (${CMAKE_INSTALL_PREFIX} STREQUAL /usr)
	
	set (LIBDIR lib${LIB_SUFFIX})
	set (INCLUDEDIR include)
	set (DATAROOTDIR share)
	set (MANDIR ${DATAROOTDIR}/man)
	set (SHAREDIR ${DATAROOTDIR}/mosquitto)
endif (WIN32)

option(WITH_TLS
	"Include SSL/TLS support?" ON)
option(WITH_TLS_PSK
	"Include TLS-PSK support (requires WITH_TLS)?" ON)
if (${WITH_TLS} STREQUAL ON)
	find_package(OpenSSL REQUIRED)
	add_definitions("-DWITH_TLS")
	if (${WITH_TLS_PSK} STREQUAL ON)
		add_definitions("-DWITH_TLS_PSK")
	endif (${WITH_TLS_PSK} STREQUAL ON)
else (${WITH_TLS} STREQUAL ON)
	set (OPENSSL_INCLUDE_DIR "")
endif (${WITH_TLS} STREQUAL ON)

option(WITH_SRV "Include SRV lookup support?" ON)

# ========================================
# Include projects
# ========================================

add_subdirectory(lib)
add_subdirectory(client)
add_subdirectory(src)
add_subdirectory(man)

# ========================================
# Install config file
# ========================================

install(FILES mosquitto.conf aclfile.example pskfile.example pwfile.example DESTINATION ${SYSCONFDIR})
