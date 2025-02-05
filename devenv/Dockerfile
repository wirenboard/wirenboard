FROM debian:bullseye
LABEL org.opencontainers.image.authors="info@wirenboard.com"
LABEL org.opencontainers.image.vendor="Wiren Board team"

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && apt install -y curl wget gnupg && \
    curl -fsSL https://deb.wirenboard.com/wirenboard-keyring.gpg > \
       /usr/share/keyrings/contactless-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/contactless-keyring.gpg] http://deb.wirenboard.com/dev-tools stable main" > \
       /etc/apt/sources.list.d/wirenboard-dev-tools.list && \
    apt-get install -y --allow-unauthenticated gnupg1 ca-certificates && \
    # TODO: add llvm dependencies to our own repository \
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/apt.llvm.org.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/apt.llvm.org.gpg] http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-15 main" > \
       /etc/apt/sources.list.d/llvm-bullseye-15.list && \
    apt update && \
    apt install -y --force-yes git gpg debootstrap proot build-essential pkg-config debhelper \
       nodejs bash-completion nano gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu sudo locales \
       devscripts python3-virtualenv equivs qemu-user-static binfmt-support node-rimraf \
       libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev debian-archive-keyring \
       libcurl4-gnutls-dev libsqlite3-dev libjsoncpp-dev sbuild kpartx zip device-tree-compiler \
       valgrind libgtest-dev google-mock cmake config-package-dev libssl-dev bc lzip lzop \
       python3-netaddr python3-pyparsing liblircclient-dev libusb-dev libusb-1.0-0-dev jq \
       python3-smbus python3-setuptools liblog4cpp5-dev libpng-dev bison flex kmod dh-python \
       clang-format clang-tidy lintian ccache \
    # for image building \
    fdisk u-boot-tools fit-aligner cpio \
    # legacy requirement for kernel building \
    rsync \
    # for Jenkins deployments \
    python3-wbci s3cmd \
    # to install fpm later for simple package building \
    ruby-rubygems && gem install fpm && \
    # for clang-tidy checks
    pip3 install compiledb

# install common build-dependencies
# TODO: remove it after full migration to sbuild
COPY common-deps.sh /root/
RUN bash -e -c 'source /root/common-deps.sh; apt-get update && apt-get install -y "${KNOWN_BUILD_DEPS[@]}"'


# FIXME: we should not install anything with --force-yes

# clang-format was previously installed from LLVM nighly repository,
# but we switched to fixed version 15.0.0-++20220704093357+5f0a054f8954-1~exp1~20220704093409.365
# to avoid unexpected changes in our source code because of new bugs/fixes in llvm.
#
# In order to make it work with wbci scripts (which treat ~exp substring in version
# as a branch version and does not add it to the staging) ~exp was repaced with ~llvmexp
# (manually using dpkg-dev and sed :) ) before uploading to WB dev-tools repo.
#
# It would be nice to update llvm from time to time though.

COPY wbdev_second_half.sh /
COPY build.sh /root/
COPY rootfs /root/rootfs
COPY boards /root/boards
COPY prep.sh /root/
COPY entrypoint.sh /sbin/
COPY chr /usr/local/bin/
COPY debootstrap-functions.diff /usr/share/debootstrap/
RUN chmod +x /root/*.sh /usr/local/bin/chr

RUN mkdir -p /var/cache/ccache && chmod 777 /var/cache/ccache
COPY schroot/fstab /etc/schroot/sbuild/fstab
COPY schroot/copyfiles /etc/schroot/sbuild/copyfiles
COPY schroot/ccache-setup /usr/local/bin/ccache-setup

# patch a bug in debootstrap/functions, preventing schroot from working inside Docker 
# see https://bugs.launchpad.net/ubuntu/+source/debootstrap/+bug/1948713
RUN patch /usr/share/debootstrap/functions < /usr/share/debootstrap/debootstrap-functions.diff

RUN echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen

RUN locale-gen && update-locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY wbdev_profile.sh /etc/profile.d/wbdev_profile.sh

RUN npm install -g bower grunt-cli
RUN rm -rf /var/lib/apt/lists/*
