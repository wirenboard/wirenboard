FROM debian:bullseye
MAINTAINER ivan4th <ivan4th@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && apt install -y wget gnupg
RUN wget -qO - https://github.com/wirenboard/keyring/raw/master/keyrings/contactless-keyring.gpg | apt-key add -
RUN wget  https://github.com/wirenboard/keyring/raw/master/keyrings/contactless-keyring.gpg --output-document=/usr/share/keyrings/contactless-keyring.gpg
RUN echo "deb [arch=amd64] http://deb.wirenboard.com/dev-tools stable main" > /etc/apt/sources.list.d/wirenboard-dev-tools.list
RUN apt-get install -y --allow-unauthenticated gnupg1 curl ca-certificates apt-transport-https
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869
RUN echo 'deb [arch=amd64] http://repo.aptly.info/ squeeze main' >/etc/apt/sources.list.d/aptly.list
RUN curl https://www.aptly.info/pubkey.txt | apt-key add -
RUN apt-get update
RUN apt-get install -y --force-yes git debootstrap
RUN apt-get install -y build-essential pkg-config debhelper
RUN apt-get install -y nodejs npm bash-completion nano gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf sudo locales
RUN apt-get install -y devscripts python3-virtualenv git equivs
RUN apt-get install -y libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev
RUN apt-get install -y libcurl4-gnutls-dev libsqlite3-dev libjsoncpp-dev
RUN apt-get install -y valgrind libgtest-dev google-mock cmake config-package-dev
RUN apt-get install -y python3-netaddr python3-pyparsing liblircclient-dev
RUN apt-get install -y libusb-dev libusb-1.0-0-dev jq python-dev python3-smbus
RUN apt-get install -y aptly python-setuptools python3-setuptools liblog4cpp5-dev libpng-dev bc lzop bison flex kmod
RUN apt-get install -y qemu-user-static binfmt-support node-rimraf
RUN apt-get install -y sbuild kpartx zip device-tree-compiler fit-aligner libssl-dev
RUN apt-get install -y debian-archive-keyring
RUN apt-get install -y --force-yes proot
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
COPY functions.diff /usr/share/debootstrap/
RUN chmod +x /root/*.sh /usr/local/bin/chr

RUN patch /usr/share/debootstrap/functions < /usr/share/debootstrap/functions.diff

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
