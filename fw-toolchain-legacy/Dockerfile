# Окружение старого сборочного ноута для сборки прошивок: Debian stretch с его
# make, gcc, python3 и git, компилятор ноута (GCC 7.3.1, binutils 2.30,
# newlib 3.0.0) и порядок файлов в каталогах, как на диске ноута.

# По умолчанию — digest индекса: Docker сам берёт из него манифест архитектуры,
# на которой идёт сборка. Под чужую архитектуру — см. ARCH в Makefile.
ARG BASE=debian:stretch@sha256:c5c5200ff1e9c73ffbf188b4a67eb1c91531b644856b4aefe86a58d2f0cb05be
# Только для загрузки исходников: в stretch устаревшие корневые сертификаты
ARG FETCH_BASE=debian:trixie-20260803@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958

# Исходники Arm и библиотеки, которые install-sources.sh иначе качает сам:
# часть его адресов умерла, поэтому архивы кладутся заранее, по sha256.
FROM ${FETCH_BASE} AS sources
ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main" \
        > /etc/apt/sources.list.d/snapshot.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl=8.14.1-2+deb13u4 ca-certificates=20250419
WORKDIR /src
RUN curl -fsSLO --retry 5 --retry-all-errors https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-src.tar.bz2 && \
    curl -fsSLO --retry 5 --retry-all-errors https://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2 && \
    curl -fsSLO --retry 5 --retry-all-errors https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2 && \
    curl -fsSLO --retry 5 --retry-all-errors https://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz && \
    curl -fsSLO --retry 5 --retry-all-errors https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.15.tar.bz2 && \
    curl -fsSLO --retry 5 --retry-all-errors https://github.com/libexpat/libexpat/releases/download/R_2_1_1/expat-2.1.1.tar.bz2 && \
    curl -fsSLO --retry 5 --retry-all-errors https://web.archive.org/web/2016id_/http://www.mr511.de/software/libelf-0.8.13.tar.gz && \
    curl -fsSLO --retry 5 --retry-all-errors https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz && \
    curl -fsSLO --retry 5 --retry-all-errors https://zlib.net/fossils/zlib-1.2.8.tar.gz && \
    printf '%s  %s\n' \
        965c5755edffbab0320736285d17de3f4189bee1801099a17f6c9aeb0218acf0 gcc-arm-none-eabi-7-2018-q2-update-src.tar.bz2 \
        498449a994efeba527885c10405993427995d3f86b8768d8cdf8d9dd7c6b73e8 gmp-6.1.0.tar.bz2 \
        d3103a80cdad2407ed581f3618c4bed04e0c92d1cf771a65ead662cc397f7775 mpfr-3.1.4.tar.bz2 \
        617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3 mpc-1.0.3.tar.gz \
        8ceebbf4d9a81afa2b4449113cee4b7cb14a687d7a549a963deb5e2a41458b6b isl-0.15.tar.bz2 \
        aff584e5a2f759dcfc6d48671e9529f6afe1e30b0cd6a4cec200cbe3f793de67 expat-2.1.1.tar.bz2 \
        591a9b4ec81c1f2042a97aa60564e0cb79d041c52faa7416acb38bc95bd2c76d libelf-0.8.13.tar.gz \
        72b24ded17d687193c3366d0ebe7cde1e6b18f0df8c55438ac95be39e8a30613 libiconv-1.14.tar.gz \
        36658cb768a54c1d4dec43c3116c27ed893e88b02ecfcb44f2166f9c0b7f2a0d zlib-1.2.8.tar.gz \
        | sha256sum -c -

# stretch снят с зеркал: пакеты остались только в archive.debian.org
FROM ${BASE} AS stretch
ENV DEBIAN_FRONTEND=noninteractive
RUN printf '%s\n' \
        "deb http://archive.debian.org/debian stretch main" \
        "deb http://archive.debian.org/debian-security stretch/updates main" \
        > /etc/apt/sources.list && \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/10-no-check-valid-until

FROM stretch AS gcc7
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential autoconf autogen bison flex gawk gperf m4 texinfo \
        libncurses5-dev bzip2 xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY --from=sources /src /build
WORKDIR /build

# Скрипты Arm — как на ноуте; пропускаются только сборка под Windows,
# документация и gdb с python. Версию в строке компилятора скрипт берёт из
# текущей даты, её фиксируем датой сборки ноута: «7-2018-q4-major».
RUN tar -xjf gcc-arm-none-eabi-7-2018-q2-update-src.tar.bz2 && \
    cd gcc-arm-none-eabi-7-2018-q2-update && \
    mv ../gmp-* ../mpfr-* ../mpc-* ../isl-* ../expat-* ../libelf-* ../libiconv-* ../zlib-* src/ && \
    sed -i 's/^\( *RELEASEDATE=\).*/\120181001/' build-common.sh && \
    ./install-sources.sh --skip_steps=mingw32 && \
    ./build-prerequisites.sh --skip_steps=mingw32 && \
    ./build-toolchain.sh --skip_steps=mingw32,manual,gdb-with-python && \
    mv install-native /opt/gcc-arm-none-eabi-7 && \
    rm -rf /opt/gcc-arm-none-eabi-7/share /build

FROM stretch

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain-legacy"
LABEL org.opencontainers.image.description="Firmware build environment of the previous build machine: stretch, gcc 7.3.1"

# Те же версии, что на ноуте: архив stretch заморожен
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential=12.3                 `# make 4.1, gcc 6.3 для юнит-тестов, libc6-dev` \
        make=4.1-9.1 \
        gcc-6=6.3.0-18+deb9u1 \
        python3=3.5.3-1                      `# скрипты сборки libwbmcu-system` \
        python=2.7.13-2                      `# make_keys_h.py старых тегов загрузчика зовёт python` \
        git=1:2.11.0-3+deb9u7                `# hash и ветка в имя артефакта, сабмодули` \
        openssh-client=1:7.4p1-10+deb9u7     `# сабмодули по git@github.com` \
        ca-certificates=20200601~deb9u2 \
        locales=2.24-11+deb9u4               `# локаль ноута en_US.UTF-8` \
        jq=1.5+dfsg-1.3                      `# манифест шифратору в джобе коробок` \
        p7zip-full=16.02+dfsg-3+deb9u1       `# комплект шифратору и его ответ` \
        python3-dateutil=2.5.3-2 && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

COPY --from=gcc7 /opt/gcc-arm-none-eabi-7 /opt/gcc-arm-none-eabi-7

# Порядок файлов в каталогах как на диске ноута: make 4.1 раскладывает
# $(wildcard ...) в порядке readdir, а от него зависит раскладка прошивки.
# Подмена подключается через make и действует на запущенные им программы; без
# EXT4_DIR_HASH_SEED она ничего не меняет. Параметры — из dumpe2fs раздела, на
# котором собирает ноут.
COPY ext4_dir_order.c make-ext4-order /tmp/
RUN gcc -O2 -shared -fPIC -o /usr/local/lib/ext4_dir_order.so /tmp/ext4_dir_order.c -ldl -lpthread && \
    install -m 755 /tmp/make-ext4-order /usr/local/bin/make && \
    rm /tmp/ext4_dir_order.c /tmp/make-ext4-order
ARG LAPTOP_DIR_HASH_SEED=279a686f-dc41-4cb3-9ea5-a387b9e6338b
ENV EXT4_DIR_HASH_SEED=${LAPTOP_DIR_HASH_SEED} \
    EXT4_DIR_BLOCK_SIZE=4096 \
    EXT4_DIR_CSUM=1

# Локаль ноута. Под POSIX Python 3.5 падает на не-ASCII в выводе скриптов сборки
ENV LANG=en_US.UTF-8
ENV PATH=/opt/gcc-arm-none-eabi-7/bin:$PATH
