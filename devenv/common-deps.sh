#!/bin/bash
#
# This file lists common deps for Wiren Board packages.
# It is included by build.sh and Dockerfile.
# It must export KNOWN_BUILD_DEPS array.

export KNOWN_BUILD_DEPS=(
    # test-suite-ng
    dh-python
    python3-all
    python3-configargparse
    python3-libgpiod
    python3-numpy
    python3-pil
    python3-qrcode
    python3-requests
    python3-pymysql
    python3-pytest
    python3-semantic-version
    python3-testinfra
    python3-tomli
    python3-tqdm
    python3-usb
    python3-wb-mcu-fw-updater
    j2cli
)
