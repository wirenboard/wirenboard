# Старый компилятор прежнего сборочного ноута: собирается так же, как там, —
# из исходников Arm 7-2018-q2-update их скриптами в Debian stretch
# (GCC 7.3.1, binutils 2.30, newlib 3.0.0). Готовых сборок под aarch64 Arm
# не выпускал, поэтому собираем на обеих архитектурах одинаково.
# Включается переменной сборки: make GCC_DIR=/opt/gcc-arm-none-eabi-7/bin/ ...
ARG GCC7_BASE=debian:stretch@sha256:c5c5200ff1e9c73ffbf188b4a67eb1c91531b644856b4aefe86a58d2f0cb05be

# По умолчанию — digest индекса: Docker сам берёт из него манифест архитектуры,
# на которой идёт сборка. Собрать под чужую архитектуру можно, подставив сюда
# digest конкретного манифеста, — см. ARCH в Makefile.
ARG BASE=debian:trixie-20260803@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958
FROM ${BASE} AS trixie

ENV DEBIAN_FRONTEND=noninteractive

ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main" \
        > /etc/apt/sources.list.d/snapshot.list

# В stretch устаревшие корневые сертификаты, https оттуда не открыть, —
# поэтому архивы качаются здесь, на основной базе.
FROM trixie AS gcc7-src

# Исходники Arm и библиотеки, которые install-sources.sh иначе качает сам:
# часть его адресов умерла, поэтому архивы кладутся заранее, по sha256.
WORKDIR /src
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl=8.14.1-2+deb13u4 ca-certificates=20250419 && \
    curl -fsSLO --retry 5 --retry-all-errors https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-src.tar.bz2 && \
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

FROM trixie

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"
LABEL org.opencontainers.image.version="0.0.1"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
# Кросс-компилятор прошивок и его libc
        gcc-arm-none-eabi=15:14.2.rel1-1         `# дебиановская сборка Arm GNU Toolchain 14.2.Rel1` \
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

COPY --from=gcc7 /opt/gcc-arm-none-eabi-7 /opt/gcc-arm-none-eabi-7
