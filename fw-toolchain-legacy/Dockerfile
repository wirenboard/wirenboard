# fw-toolchain со старым компилятором прежнего сборочного ноута первым в PATH:
# GCC 7.3.1, binutils 2.30, newlib 3.0.0. Компилятор собирается так же, как на
# ноуте, — из исходников Arm 7-2018-q2-update их скриптами в Debian stretch.
# Готовых сборок под aarch64 Arm не выпускал, поэтому собираем на обеих
# архитектурах одинаково.
ARG BASE=registry.wirenboard.com/wirenboard/fw-toolchain:latest
ARG GCC7_BASE=debian:stretch@sha256:c5c5200ff1e9c73ffbf188b4a67eb1c91531b644856b4aefe86a58d2f0cb05be

# Исходники Arm и библиотеки, которые install-sources.sh иначе качает сам:
# часть его адресов умерла, поэтому архивы кладутся заранее, по sha256.
# Качаем на основной базе: в stretch устаревшие корневые сертификаты.
FROM ${BASE} AS gcc7-src
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

FROM ${GCC7_BASE} AS gcc7

RUN printf '%s\n' \
        "deb http://archive.debian.org/debian stretch main" \
        "deb http://archive.debian.org/debian-security stretch/updates main" \
        > /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential autoconf autogen bison flex gawk gperf m4 texinfo \
        libncurses5-dev bzip2 xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY --from=gcc7-src /src /build
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

FROM ${BASE}

LABEL org.opencontainers.image.title="fw-toolchain-legacy"
LABEL org.opencontainers.image.description="fw-toolchain with gcc 7.3.1 of the previous firmware build machine"

COPY --from=gcc7 /opt/gcc-arm-none-eabi-7 /opt/gcc-arm-none-eabi-7
ENV PATH=/opt/gcc-arm-none-eabi-7/bin:$PATH
