FROM debian:forky@sha256:918ae9bd6b6afc8a5c7a7a160623c1147fca67f55b277132e6effa987d4d5d5c

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"
LABEL org.opencontainers.image.version="0.0.1"

ENV DEBIAN_FRONTEND=noninteractive

# База — Debian forky (testing): выбрана ради host-компилятора GCC 15.3 —
# той же ветки, что и кросс-тулчейн Arm GNU 15.3.Rel1 ниже. Так юнит-тесты
# (host gcc) и прошивки (arm-none-eabi-gcc) собираются одной версией GCC с
# одинаковой диагностикой. В stable (trixie) host gcc только 14.2.
#
# Воспроизводимость: базовый образ зафиксирован контрольной суммой — sha256
# после «@» в FROM. Docker сверяет скачанное с ней, поэтому при любой
# пересборке берётся байт-в-байт тот же образ (одна сумма покрывает оба
# варианта, amd64 и arm64). Пакеты ставятся из snapshot.debian.org на
# фиксированную дату и с явными версиями: apt-get update видит один и тот же
# срез архива, и при пересборке не «прилетит» ничего нового, пока дату и
# версии не подняли руками (вместе, одним PR).
ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ forky main" \
        > /etc/apt/sources.list.d/snapshot.list

# Host gcc 15 — для юнит-тестов (Unity), python3 — для
# check_flash_size/check_reg_overlaps/log_print_gen из libwbmcu-system,
# gcovr — для make coverage (тесты библиотек), s3cmd + curl — для стадий
# выгрузки карт регистров и прошивок (wbfw-s3-uploader) в CI,
# xz-utils — распаковка тарбола Arm GNU Toolchain (ниже).
RUN apt-get update && \
    apt-get install -y \
        git=1:2.53.0-1 \
        python3=3.14.6-1 \
        make=4.4.1-3 \
        gcc=4:15.2.0-5 \
        gcc-15=15.3.0-2 \
        gcovr=7.2+really-2 \
        s3cmd=2.4.0-3 \
        curl=8.21.0-2 \
        ca-certificates=20260601 \
        xz-utils=5.8.3-1 && \
    rm -rf /var/lib/apt/lists/*

# Хостовый x86-gcc сам по себе принимает -m32; глушим его обёрткой, чтобы
# сборка с -m32 падала с одной и той же явной ошибкой на amd64- и arm64-хостах.
RUN printf '%s\n' \
        '#!/bin/sh' \
        'for a in "$@"; do' \
        '    if [ "$a" = "-m32" ]; then' \
        '        echo "fw-toolchain: -m32 is not supported; the build fails identically on amd64 and arm64 hosts" >&2' \
        '        exit 1' \
        '    fi' \
        'done' \
        'exec /usr/bin/gcc "$@"' \
        > /usr/local/bin/gcc && \
    chmod +x /usr/local/bin/gcc

# Кросс-компилятор — Arm GNU Toolchain 15.3.Rel1 (GCC 15.3.1), самый свежий
# стабильный релиз Arm; официальный тарбол с gitlab.arm.com (в Debian только 14.2).
# Пин — версией релиза и sha256. Версия зафиксирована жёстко: flash/RAM-лимиты
# прошивок чувствительны к версии компилятора, обновление — осознанным PR с
# прогоном сборки всех прошивок.
# Тарбол выбирается по архитектуре хоста сборки (TARGETARCH подставляет
# BuildKit): amd64 = любой x86-64 (Intel и AMD), arm64 = aarch64 (ARM-маки,
# ARM-серверы). Других Linux-хостов у Arm GNU Toolchain не существует.
ARG ARM_GNU_VERSION=15.3.rel1
ARG ARM_GNU_SHA256_X86_64=563bebb2b97d53382b956d6ee1fe61e2cae26699901417234a37df505ef9b5fa
ARG ARM_GNU_SHA256_AARCH64=06979e0c8171de58e5dc2a2b2019330a290f30930f27728af98a83e1a7369b3a
ARG TARGETARCH
RUN case "$TARGETARCH" in \
        amd64) host=x86_64;  sha="$ARM_GNU_SHA256_X86_64" ;; \
        arm64) host=aarch64; sha="$ARM_GNU_SHA256_AARCH64" ;; \
        *) echo "unsupported TARGETARCH='$TARGETARCH'" >&2; exit 1 ;; \
    esac && \
    tarball="arm-gnu-toolchain-$ARM_GNU_VERSION-$host-arm-none-eabi.tar.xz" && \
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "/tmp/$tarball" \
        "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/$ARM_GNU_VERSION/$tarball" && \
    echo "$sha  /tmp/$tarball" | sha256sum -c - && \
    mkdir -p /opt/arm-gnu-toolchain && \
    tar -C /opt/arm-gnu-toolchain --strip-components=1 -xJf "/tmp/$tarball" && \
    rm "/tmp/$tarball" && \
    rm -rf /opt/arm-gnu-toolchain/share/doc /opt/arm-gnu-toolchain/share/man && \
    ln -s /opt/arm-gnu-toolchain/bin/arm-none-eabi-* /usr/local/bin/
