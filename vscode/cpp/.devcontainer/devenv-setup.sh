#!/bin/bash

TARGET="wb8"

case ${TARGET} in
    wb8) ARCH=arm64 ;;
    *)   ARCH=armhf ;;
esac

DIR=$(pwd)
CHROOT="schroot -c bullseye-amd64-sbuild --directory=${DIR} --"

echo "${DIR} ${DIR} none rw,bind 0 0" >> /etc/schroot/sbuild/fstab

LIST=$(${CHROOT} dpkg-checkbuilddeps 2>&1 | sed 's/dpkg-checkbuilddeps:\serror:\sUnmet build dependencies: //g' | sed 's/[\(][^)]*[\)] *//g')
DEPS=()

for ITEM in ${LIST}; do
    if [[ ${ITEM} != *:all ]]; then
        ITEM+=":${ARCH}"
    fi
    DEPS+=(${ITEM})
done

${CHROOT} bash -c "echo \"deb http://deb.wirenboard.com/${TARGET}/bullseye unstable main\" > /etc/apt/sources.list.d/wirenboard-unstable.list"
${CHROOT} apt-get update
${CHROOT} apt install -y ${DEPS[@]}

apt update
apt install gdb-multiarch
