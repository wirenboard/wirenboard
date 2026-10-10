# По умолчанию — digest индекса: Docker сам берёт из него манифест архитектуры,
# на которой идёт сборка. Собрать под чужую архитектуру можно, подставив сюда
# digest конкретного манифеста, — см. ARCH в Makefile.
ARG BASE=debian:trixie-20260803@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958
FROM ${BASE}

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"
LABEL org.opencontainers.image.version="0.0.1"

ENV DEBIAN_FRONTEND=noninteractive

ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main" \
        > /etc/apt/sources.list.d/snapshot.list

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
        bzip2=1.0.8-6                            `# распаковка архива старого компилятора` \
# Дополнительное для удобства ручной работы в образе:
        nano=8.4-1+deb13u1                       `# правка файлов на месте` \
        less=668-1                               `# пейджер для git log и diff` \
        jq=1.7.1-6+deb13u2                       `# смотреть targets_memory_report.json` \
        xxd=2:9.1.1230-2                         `# смотреть bin глазами` && \
    rm -rf /var/lib/apt/lists/*

# Старый компилятор, как на прежнем сборочном ноуте: Arm 7-2018-q2-update,
# GCC 7.3.1 + binutils 2.30 + newlib 3.0.0. Включается переменной сборки:
# make GCC_DIR=/opt/gcc-arm-none-eabi-7/bin/ ...
# Arm выпускал его только под x86_64, поэтому в arm64-образе его нет.
ARG GCC7_URL=https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
ARG GCC7_SHA256=bb17109f0ee697254a5d4ae6e5e01440e3ea8f0277f2e8169bf95d07c7d5fe69
RUN if [ "$(dpkg --print-architecture)" = amd64 ]; then \
        curl -fsSL -o /tmp/gcc7.tar.bz2 "$GCC7_URL" && \
        echo "$GCC7_SHA256  /tmp/gcc7.tar.bz2" | sha256sum -c - && \
        mkdir /opt/gcc-arm-none-eabi-7 && \
        tar -xjf /tmp/gcc7.tar.bz2 -C /opt/gcc-arm-none-eabi-7 --strip-components=1 && \
        rm -rf /tmp/gcc7.tar.bz2 /opt/gcc-arm-none-eabi-7/share; \
    fi
