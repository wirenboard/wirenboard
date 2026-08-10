FROM debian:trixie@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"

ENV DEBIAN_FRONTEND=noninteractive

# Воспроизводимость: база запинена дайджестом (мульти-арх индекс trixie,
# amd64+arm64), пакеты ставятся из snapshot.debian.org на фиксированную дату
# и с явными версиями. apt-get update видит один и тот же срез архива, поэтому
# при пересборке образа не «прилетит» ничего нового, пока дату и версии не
# подняли руками (вместе, одним PR).
ARG SNAPSHOT=20260810T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources && \
    { \
      echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie main"; \
      echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT/ trixie-updates main"; \
      echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/$SNAPSHOT/ trixie-security main"; \
    } > /etc/apt/sources.list.d/snapshot.list

# gcc-arm-none-eabi зафиксирован не только ради воспроизводимости: flash/RAM-лимиты
# прошивок чувствительны к версии компилятора (gcc 8 из bullseye превышает лимиты
# на впритык-таргетах, 14.2 из trixie — проходит). Следующая итерация — Arm GNU
# Toolchain 15.2.Rel1 тарболом, после фиксов
# -Werror=unterminated-string-initialization в libwbmcu-*.
# Host gcc — для юнит-тестов (Unity), python3 — для
# check_flash_size/check_reg_overlaps/log_print_gen из libwbmcu-system,
# gcovr — для make coverage (тесты библиотек), s3cmd + curl — для стадий
# выгрузки карт регистров и прошивок (wbfw-s3-uploader) в pipeline-либе,
# qemu-system-arm — прогон layout-чувствительных тестов и генераторов
# flashfs-дампов настоящим таргет-компилятором на эмуляторе Cortex-M
# (semihosting), одинаково на amd64- и arm64-хостах.
# Образ публикуется multi-arch (разработчики на ARM-машинах собирают в том же
# окружении); gcc-multilib существует только на amd64 — он нужен юнит-тестам,
# собирающимся с -m32 (на arm64 такие тесты не гоняются).
RUN apt-get update && \
    apt-get install -y \
        git=1:2.47.3-0+deb13u1 \
        python3=3.13.5-1 \
        make=4.4.1-2 \
        gcc=4:14.2.0-1 \
        gcc-arm-none-eabi=15:14.2.rel1-1 \
        gcovr=7.2+really-1.1 \
        s3cmd=2.4.0-3 \
        curl=8.14.1-2+deb13u4 \
        ca-certificates=20250419 \
        qemu-system-arm=1:10.0.11+ds-0+deb13u1 && \
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        apt-get install -y gcc-multilib=4:14.2.0-1; \
    fi && \
    rm -rf /var/lib/apt/lists/*
