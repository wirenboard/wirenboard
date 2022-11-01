FROM debian:bullseye
MAINTAINER ivan4th <ivan4th@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && apt install -y wget gnupg && \
    wget -qO - https://github.com/wirenboard/keyring/raw/master/keyrings/contactless-keyring.gpg \
       | apt-key add - && \
    wget  https://github.com/wirenboard/keyring/raw/master/keyrings/contactless-keyring.gpg \
       --output-document=/usr/share/keyrings/contactless-keyring.gpg && \
    echo "deb [arch=amd64] http://deb.wirenboard.com/dev-tools stable main" > \
       /etc/apt/sources.list.d/wirenboard-dev-tools.list && \
    apt-get install -y --allow-unauthenticated gnupg1 curl ca-certificates apt-transport-https && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869 && \
    # TODO: add llvm dependencies to our own repository \
    curl https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb [arch=amd64] http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-15 main" > \
       /etc/apt/sources.list.d/llvm-bullseye-15.list && \
    \
    # Low-priority testing repo for pinning pylint \
    echo "deb http://deb.debian.org/debian testing main" > /etc/apt/sources.list.d/testing.list && \
    echo 'Package: *\nPin: release a=testing\nPin-Priority: 70\n\n\
Package: pylint python3-astroid python3-typing-extensions\nPin: release a=testing\nPin-Priority: 900' > \
 /etc/apt/preferences.d/pylint-from-testing.pref && \
    \
    apt update &&\
    apt install -y --force-yes git debootstrap proot build-essential pkg-config debhelper \
       nodejs npm bash-completion nano gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf sudo locales \
       devscripts python3-virtualenv git equivs qemu-user-static binfmt-support node-rimraf \
       libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev debian-archive-keyring \
       libcurl4-gnutls-dev libsqlite3-dev libjsoncpp-dev sbuild kpartx zip device-tree-compiler \
       valgrind libgtest-dev google-mock cmake config-package-dev libssl-dev bc lzop \
       python3-netaddr python3-pyparsing liblircclient-dev libusb-dev libusb-1.0-0-dev jq \
       python3-smbus python3-setuptools liblog4cpp5-dev libpng-dev bison flex kmod dh-python \
       clang-format \
    # for image building \
    fdisk u-boot-tools fit-aligner \
    # legacy requirement for kernel building \
    rsync  \
    # legacy requirement for go-required packages \
    golang-go \
    # for Jenkins python checks
    pylint black python3-isort


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
 
# Go environment
# from https://github.com/docker-library/golang/blob/master/1.5/Dockerfile
ENV GOLANG_VERSION 1.13.1
ENV GOLANG_DOWNLOAD_URL   https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA1  e9275a46508483242feb6200733b6382f127cb43
 
RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz
 
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
 
COPY wbdev_second_half.sh /
COPY build.sh /root/
COPY rootfs /root/rootfs
COPY boards /root/boards
COPY prep.sh /root/
COPY entrypoint.sh /sbin/
COPY projects.list /
COPY chr /usr/local/bin/
COPY debootstrap-functions.diff /usr/share/debootstrap/
RUN chmod +x /root/*.sh /usr/local/bin/chr

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
