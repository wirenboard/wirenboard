FROM debian:bullseye
MAINTAINER Nikita Maslov <nikita.maslov@wirenboard.ru>
 
ENV DEBIAN_FRONTEND noninteractive
 
RUN echo "deb [arch=amd64] http://deb.wirenboard.com/dev-tools stable main" > /etc/apt/sources.list.d/wirenboard-dev-tools.list && \
    apt-get update --allow-unauthenticated -o Acquire::AllowInsecureRepositories=true \
                                           -o Acquire::AllowDowngradeToInsecureRepositories=true && \
    apt-get install -y --allow-unauthenticated gnupg2 contactless-keyring && \
    apt-get update && \
    apt-get install -y --force-yes git curl ca-certificates wget debootstrap \
      build-essential pkg-config debhelper    \
      nodejs npm node-rimraf bash-completion nano gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf sudo locales \
      devscripts equivs rsync \
      libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev \
      libcurl4-gnutls-dev libsqlite3-dev libjsoncpp-dev \
      valgrind libgtest-dev google-mock cmake config-package-dev \
      libusb-dev libusb-1.0-0-dev jq \
      aptly python-setuptools python3-setuptools dh-python liblog4cpp5-dev bc lzop bison flex kmod \
      qemu-user-static binfmt-support \
      sbuild kpartx zip device-tree-compiler u-boot-tools fit-aligner libssl-dev \
      golang-1.15-go golang-go clang-format \
      swig libpython2-dev libpython3-dev \
      fdisk && \
    apt-get install -y --force-yes proot
# FIXME: we should not install anything with --force-yes
 
COPY wbdev_second_half.sh /
COPY build.sh /root/
COPY rootfs /root/rootfs
COPY boards /root/boards
COPY prep.sh /root/
COPY entrypoint.sh /sbin/
COPY projects.list /
COPY chr /usr/local/bin/
RUN chmod +x /root/*.sh /usr/local/bin/chr

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
