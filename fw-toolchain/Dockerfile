# По умолчанию — digest индекса: Docker сам берёт из него манифест архитектуры,
# на которой идёт сборка. Собрать под чужую архитектуру можно, подставив сюда
# digest конкретного манифеста, — см. ARCH в Makefile.
ARG BASE=debian:trixie-20260803@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958
ARG SNAPSHOT=20260810T000000Z
# Версия кросс-компилятора — одна на обе стадии: cc1 для покрытия собирается из
# исходников ровно того пакета, что стоит в образе (см. стадию gcov-flag-cc1)
ARG ARM_GCC_VERSION=15:14.2.rel1-1

# cc1 для покрытия прошивок на железе (gcov flag mode, README → «Coverage on
# hardware»). Исходники — пакет gcc-arm-none-eabi-source той же версии, что и
# штатный компилятор, плюс патчи из gcov-flag/. В образ уходит только cc1,
# сборочные зависимости остаются в этой стадии.
FROM ${BASE} AS gcov-flag-cc1
ARG SNAPSHOT
ARG ARM_GCC_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main" \
        > /etc/apt/sources.list.d/snapshot.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc-arm-none-eabi-source=$ARM_GCC_VERSION `# исходники штатного кросс-компилятора с патчами Debian` \
        binutils-arm-none-eabi                   `# configure проверяет возможности ассемблера; без пина — см. README` \
        g++=4:14.2.0-1                           `# host-компилятор для сборки cc1` \
        g++-14=14.2.0-19                         `# пин конкретной версии под метапакетом` \
        make=4.4.1-2                             `# сборка` \
        libgmp-dev=2:6.3.0+dfsg-3                `# библиотеки, с которыми слинкован и штатный cc1:` \
        libmpfr-dev=4.2.2-1                      `#   их runtime-части в итоговом образе уже есть` \
        libmpc-dev=1.3.1-1+b3                    `#   как зависимости gcc-arm-none-eabi` \
        libisl-dev=0.27-1                        \
        zlib1g-dev=1:1.3.dfsg+really1.3.1-1+b1   `# --with-system-zlib, как у Debian` \
        flex=2.6.4-8.2+b4                        `# лексер gengtype` \
        gawk                                     `# скрипты сборки GCC, как у Debian; binNMU разный на amd64 и arm64` \
        patch=2.8-2                              `# наложение патчей` \
        xz-utils=5.8.1-1+deb13u1                 `# распаковка исходников` && \
    rm -rf /var/lib/apt/lists/*

COPY gcov-flag/*.patch /src/patches/
RUN mkdir /src/gcc && \
    tar -xJf /usr/src/gcc-arm-none-eabi-source.tar.xz -C /src/gcc && \
    for p in /src/patches/*.patch; do patch -p1 -d /src/gcc < "$p" || exit 1; done

# Флаги — из debian/rules пакета, кроме языков (нужен только cc1) и pkgversion:
# пометка +gcov-flag попадает в .comment, и покрытую сборку видно по ELF
RUN mkdir /src/build && cd /src/build && \
    /src/gcc/configure \
        --target=arm-none-eabi \
        --prefix=/usr/lib --bindir=/usr/bin --libexecdir=/usr/lib --libdir=/usr/lib \
        --enable-languages=c \
        --enable-multilib --with-multilib-list=rmprofile,aprofile \
        --disable-decimal-float --disable-libffi --disable-libgomp --disable-libmudflap \
        --disable-libquadmath --disable-libssp --disable-libstdcxx-pch --disable-libstdcxx \
        --disable-nls --disable-shared --disable-threads --enable-tls \
        --with-system-zlib --with-gnu-as --with-gnu-ld --without-included-gettext \
        --with-headers=no --without-newlib \
        "--with-pkgversion=$ARM_GCC_VERSION+gcov-flag" \
        AR_FOR_TARGET=arm-none-eabi-ar AS_FOR_TARGET=arm-none-eabi-as \
        LD_FOR_TARGET=arm-none-eabi-ld NM_FOR_TARGET=arm-none-eabi-nm \
        OBJDUMP_FOR_TARGET=arm-none-eabi-objdump RANLIB_FOR_TARGET=arm-none-eabi-ranlib \
        READELF_FOR_TARGET=arm-none-eabi-readelf STRIP_FOR_TARGET=arm-none-eabi-strip && \
    make -j"$(nproc)" all-gcc && \
    strip gcc/cc1

FROM ${BASE}
ARG SNAPSHOT
ARG ARM_GCC_VERSION

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"
LABEL org.opencontainers.image.version="0.0.1"

ENV DEBIAN_FRONTEND=noninteractive

RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main" \
        > /etc/apt/sources.list.d/snapshot.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
# Кросс-компилятор прошивок и его libc
        gcc-arm-none-eabi=$ARM_GCC_VERSION       `# дебиановская сборка Arm GNU Toolchain 14.2.Rel1` \
        libnewlib-arm-none-eabi=4.5.0.20241231-1 `# newlib + nano/rdimon/nosys specs` \
# Host-компилятор и заголовки его libc — юнит-тесты Unity
        gcc=4:14.2.0-1                           `# та же ветка GCC 14.2, что и кросс` \
        gcc-14=14.2.0-19                         `# пин конкретной версии под метапакетом` \
        libc6-dev=2.41-12+deb13u3                `# без него нет stdio.h и тесты не собрать` \
# Сборка
        make=4.4.1-2                             `# сборка` \
        python3=3.13.5-1                         `# скрипты сборки libwbmcu-system` \
        git=1:2.47.3-0+deb13u1                   `# hash и ветка в имя артефакта, сабмодули` \
        openssh-client=1:10.0p1-7+deb13u4        `# сабмодули по git@github.com` \
# Анализ артефактов и отчёты
        python3-pyelftools=0.32-1                `# разбор ELF для func_graph` \
        gcovr=7.2+really-1.1                     `# отчёт покрытия, make coverage` \
# Стадии CI
        s3cmd=2.4.0-3                            `# выгрузка карт регистров и прошивок в S3` \
        curl=8.14.1-2+deb13u4                    `# HTTP в стадиях CI` \
        python3-requests=2.32.3+dfsg-5+deb13u1   `# HTTP во вспомогательных скриптах` \
        ca-certificates=20250419                 `# корневые сертификаты для https` \
        7zip=25.01+dfsg-1~deb13u2                `# AES-256 архив комплекта для шифратора` \
        python3-ruamel.yaml=0.18.10+ds-1         `# чтение реестра ключей резолвером; дубликат ключа в yaml — ошибка` \
# Дополнительное для удобства ручной работы в образе:
        nano=8.4-1+deb13u1                       `# правка файлов на месте` \
        less=668-1                               `# пейджер для git log и diff` \
        jq=1.7.1-6+deb13u2                       `# смотреть targets_memory_report.json` \
        xxd=2:9.1.1230-2                         `# смотреть bin глазами` && \
    rm -rf /var/lib/apt/lists/*

# cc1 для покрытия на железе. Штатный cc1 не заменяется: патченный подключается
# к тому же драйверу только явно, GCOV_FLAG_MODE=1 arm-none-eabi-gcc -B/opt/gcov-flag/
COPY --from=gcov-flag-cc1 /src/build/gcc/cc1 /opt/gcov-flag/cc1

# Самопроверка. Без GCOV_FLAG_MODE патченный cc1 обязан выдавать тот же asm, что
# штатный (разница — только .ident с pkgversion), и с --coverage, и без него.
# С GCOV_FLAG_MODE=1 счётчики покрытия — флаги: strb вместо 64-битного adds/adcs.
# -frandom-seed убирает из gcov-штампа время компиляции, иначе asm не сравнить
RUN cd /tmp && \
    printf 'int f(int x) { return x > 0 ? x * 2 : -x; }\n' > probe.c && \
    cc='arm-none-eabi-gcc -mcpu=cortex-m23 -mthumb -Os -frandom-seed=probe -S -o probe.s probe.c' && \
    for cov in '' --coverage; do \
        $cc $cov && grep -v '\.ident' probe.s > stock.cmp && \
        $cc $cov -B/opt/gcov-flag/ && grep -v '\.ident' probe.s > patched.cmp && \
        grep -q '+gcov-flag' probe.s && \
        cmp stock.cmp patched.cmp || exit 1; \
    done && \
    grep -q adcs stock.cmp && \
    GCOV_FLAG_MODE=1 $cc --coverage -B/opt/gcov-flag/ && \
    grep -q strb probe.s && ! grep -q adcs probe.s && \
    rm probe.* *.cmp
