FROM debian:stretch
MAINTAINER ivan4th <ivan4th@gmail.com>
 
ENV DEBIAN_FRONTEND noninteractive

# clang-format was previously installed from LLVM nighly repository,
# but we switched to fixed version 15.0.0-++20220704093357+5f0a054f8954-1~exp1~20220704093409.365
# to avoid unexpected changes in our source code because of new bugs/fixes in llvm.
#
# In order to make it work with wbci scripts (which treat ~exp substring in version
# as a branch version and does not add it to the staging) ~exp was repaced with ~llvmexp
# (manually using dpkg-dev and sed :) ) before uploading to WB dev-tools repo.
#
# It would be nice to update llvm from time to time though.

RUN echo "deb [arch=amd64] http://deb.wirenboard.com/dev-tools stable main" > /etc/apt/sources.list.d/wirenboard-dev-tools.list && \
    echo "deb [arch=amd64] http://deb.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/stretch-backports.list && \
    echo -n "Package: node* npm libuv1*\nPin: release a=stretch-backports\nPin-Priority: 510" > /etc/apt/preferences.d/01nodejs && \
    apt-get update && \
    apt-get install -y --allow-unauthenticated gnupg1 curl ca-certificates apt-transport-https contactless-keyring && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AEE07869 && \
    echo 'deb [arch=amd64] http://repo.aptly.info/ squeeze main' >/etc/apt/sources.list.d/aptly.list && \
    curl https://www.aptly.info/pubkey.txt | apt-key add - && \ 
    apt-get update && \
    apt-get install -y --force-yes git mercurial curl wget debootstrap \
      build-essential pkg-config debhelper    \
      nodejs npm bash-completion nano gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf sudo locales \
      devscripts python-virtualenv git equivs \
      libmosquittopp-dev libmosquitto-dev pkg-config gcc g++ libmodbus-dev \
      libcurl4-gnutls-dev libsqlite3-dev libjsoncpp-dev \
      valgrind libgtest-dev google-mock cmake config-package-dev \
      python-netaddr python-pyparsing liblircclient-dev \
      libusb-dev libusb-1.0-0-dev jq python-dev python-smbus \
      aptly python-setuptools python3-setuptools liblog4cpp5-dev libpng-dev libqt4-dev bc lzop bison flex kmod \
      qemu-user-static binfmt-support node-rimraf \
      sbuild kpartx zip device-tree-compiler u-boot-tools=2016.11+dfsg1-4 fit-aligner libssl-dev \
      golang-go clang-format \
      debian-archive-keyring && \
    apt-get install -y --force-yes proot
# FIXME: we should not install anything with --force-yes
 
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
RUN chmod +x /root/*.sh /usr/local/bin/chr

RUN echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen

RUN locale-gen && update-locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# build and install google test
RUN (cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/)
RUN (ln -s /usr/src/gtest /usr/src/gmock/gtest)
RUN (cd /usr/src/gmock && cmake . && make && mv libg* /usr/lib/)

COPY wbdev_profile.sh /etc/profile.d/wbdev_profile.sh

RUN npm install -g bower grunt-cli
RUN rm -rf /var/lib/apt/lists/*
