FROM debian:jessie
MAINTAINER ivan4th <ivan4th@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y curl ca-certificates && \
    curl http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | apt-key add - && \
    echo 'deb http://emdebian.org/tools/debian/ jessie main' >/etc/apt/sources.list.d/crosstools.list && \
    dpkg --add-architecture armel && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y git mercurial curl wget debootstrap \
      proot build-essential pkg-config pkg-config:armel debhelper npm \
      nodejs-legacy bash-completion nano gcc-arm-linux-gnueabi sudo \
      locales

# Go environment
# from https://github.com/docker-library/golang/blob/master/1.5/Dockerfile
ENV GOLANG_VERSION 1.5.1
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA1 46eecd290d8803887dec718c691cc243f2175fe0

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA1  golang.tar.gz" | sha1sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

COPY build.sh /root/
COPY rootfs /root/rootfs
COPY prep.sh /root/
COPY configs /root/
COPY entrypoint.sh /sbin/
COPY chr /usr/local/bin/
RUN chmod +x /root/*.sh /usr/local/bin/chr

COPY configs/configs/etc/locale.gen.wb /etc/locale.gen
RUN locale-gen && update-locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN /bin/echo 'export TERM=xterm' >/tmp/bash.bashrc && \
    /bin/echo 'export GOPATH="$HOME/go"' >>/tmp/bash.bashrc && \
    /bin/echo 'export PATH="/usr/local/go/bin:$PATH"' >>/tmp/bash.bashrc && \
    /bin/echo 'mkdir -p "$GOPATH"' >>/tmp/bash.bashrc && \
    cat /etc/bash.bashrc >>/tmp/bash.bashrc && \
    mv /tmp/bash.bashrc /etc/bash.bashrc && \
    /bin/echo '[ -f /.devdir ] && cd "$(cat /.devdir)"' >/etc/profile.d/devdir.sh

RUN npm install -g bower grunt-cli