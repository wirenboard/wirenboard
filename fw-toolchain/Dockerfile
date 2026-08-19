FROM debian:forky@sha256:918ae9bd6b6afc8a5c7a7a160623c1147fca67f55b277132e6effa987d4d5d5c

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"

ENV DEBIAN_FRONTEND=noninteractive

# База — Debian forky (testing): выбрана ради host-компилятора GCC 15.3 —
# той же ветки, что и кросс-тулчейн Arm GNU 15.3.Rel1 ниже. Так юнит-тесты
# (host gcc) и прошивки (arm-none-eabi-gcc) собираются одной версией GCC с
# одинаковой диагностикой. В stable (trixie) host gcc только 14.2.
#
# Воспроизводимость: база запинена дайджестом (мульти-арх индекс forky,
# amd64+arm64), пакеты ставятся из snapshot.debian.org на фиксированную дату
# и с явными версиями. apt-get update видит один и тот же срез архива, поэтому
# при пересборке образа не «прилетит» ничего нового, пока дату и версии не
# подняли руками (вместе, одним PR).
ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ forky main" \
        > /etc/apt/sources.list.d/snapshot.list

# Host gcc (мета gcc → gcc-15) — для юнит-тестов (Unity), python3 — для
# check_flash_size/check_reg_overlaps/log_print_gen из libwbmcu-system,
# gcovr — для make coverage (тесты библиотек), s3cmd + curl — для стадий
# выгрузки карт регистров и прошивок (wbfw-s3-uploader) в pipeline-либе,
# qemu-system-arm — прогон layout-чувствительных тестов и генераторов
# flashfs-дампов настоящим таргет-компилятором на эмуляторе Cortex-M
# (semihosting), одинаково на amd64- и arm64-хостах,
# xz-utils — распаковка тарбола Arm GNU Toolchain (ниже).
# Образ публикуется multi-arch (разработчики на ARM-машинах собирают в том же
# окружении); gcc-multilib существует только на amd64 — он нужен юнит-тестам,
# собирающимся с -m32 (на arm64 такие тесты не гоняются). Целевое состояние —
# перевод тестов на RUN_ON_QEMU (тот же arm-none-eabi-gcc + qemu), после чего
# host gcc и multilib из образа уйдут совсем.
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
        xz-utils=5.8.3-1 \
        qemu-system-arm=1:11.0.3+ds-2 && \
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        apt-get install -y gcc-multilib=4:15.2.0-5 gcc-15-multilib=15.3.0-2; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Кросс-компилятор — Arm GNU Toolchain 15.3.Rel1 (GCC 15.3.1), самый свежий
# стабильный релиз Arm; официальный тарбол с gitlab.arm.com.
# Пин — версией релиза и sha256 обоих хостовых вариантов (amd64/arm64).
# Версия зафиксирована жёстко: flash/RAM-лимиты прошивок чувствительны к версии
# компилятора; известные особенности gcc15 на кодовой базе libwbmcu отражены в
# исследовании FW-1284 (research/compiler-study): гейт -fno-optimize-crc для
# MAP-таргетов и -Werror=unterminated-string-initialization в SIG_*-INTERNAL
# сборках — правки на стороне реп прошивок, не образа.
ARG ARM_GNU_VERSION=15.3.rel1
ARG ARM_GNU_SHA256_AMD64=563bebb2b97d53382b956d6ee1fe61e2cae26699901417234a37df505ef9b5fa
ARG ARM_GNU_SHA256_ARM64=06979e0c8171de58e5dc2a2b2019330a290f30930f27728af98a83e1a7369b3a
ARG TARGETARCH
RUN case "$TARGETARCH" in \
        amd64) host=x86_64;  sha="$ARM_GNU_SHA256_AMD64" ;; \
        arm64) host=aarch64; sha="$ARM_GNU_SHA256_ARM64" ;; \
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
