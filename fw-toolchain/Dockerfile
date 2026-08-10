FROM debian:trixie

LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"
LABEL org.opencontainers.image.title="fw-toolchain"
LABEL org.opencontainers.image.description="Build environment for classic libwbmcu-based MCU firmware"

ENV DEBIAN_FRONTEND=noninteractive

# gcc-arm-none-eabi намеренно зафиксирован попакетно: flash/RAM-лимиты прошивок
# чувствительны к версии компилятора (gcc 8 из bullseye превышает лимиты на
# впритык-таргетах, 14.2 из trixie — проходит). Следующая итерация — Arm GNU
# Toolchain 15.2.Rel1 тарболом, после фиксов
# -Werror=unterminated-string-initialization в libwbmcu-*.
# Host gcc — для юнит-тестов (Unity), python3 — для
# check_flash_size/check_reg_overlaps/log_print_gen из libwbmcu-system,
# gcovr — для make coverage (тесты библиотек), s3cmd + curl — для стадий
# выгрузки карт регистров и прошивок (wbfw-s3-uploader) в pipeline-либе.
# Образ рассчитан на multi-arch публикацию (разработчики на ARM-машинах должны
# собирать в том же окружении); gcc-multilib существует только на amd64 —
# он нужен юнит-тестам, собирающимся с -m32 (на arm64 такие тесты не гоняются).
RUN apt-get update && \
    apt-get install -y git python3 make gcc gcc-arm-none-eabi=15:14.2.rel1-1 \
                       gcovr s3cmd curl ca-certificates && \
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        apt-get install -y gcc-multilib; \
    fi && \
    rm -rf /var/lib/apt/lists/*
