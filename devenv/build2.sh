#!/bin/bash
set -u -e
cd /root

export LC_ALL=C LANGUAGE=C LANG=C
export GOLANG_VERSION="1.13.1"
export GOLANG_DOWNLOAD_URL="https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz"


#Добавим источники пакетов:
chroot $TARGET_ROOTFS /bin/bash -e <<EOF
echo deb [arch=amd64] http://releases.contactless.ru/stable/$TARGET_VERSION $TARGET_VERSION main > /etc/apt/sources.list.d/contactless.list
sed -e "s/httpredir.debian.org/mirror.yandex.ru/g" -i /etc/apt/sources.list
apt-get update
#build-essential:native,libjsoncpp-dev,libcurl-dev
apt-get install -y build-essential libjsoncpp-dev libcurl4-gnutls-dev
EOF

chroot $TARGET_ROOTFS /bin/bash -e <<EOF
#echo $GOLANG_VERSION >>/root/log.txt
#export >>/root/log.txt
cd /usr/src
curl -fsSL "\$GOLANG_DOWNLOAD_URL" -o golang.tar.gz
tar -C /usr/local -xzf golang.tar.gz
rm golang.tar.gz
GOPATH=/go 
PATH=\$GOPATH/bin:/usr/local/go/bin:\$PATH 
mkdir -p "\$GOPATH/src" "\$GOPATH/bin" && chmod -R 777 "\$GOPATH" 
EOF


export GLIDE_VERSION="v0.13.1"
export GLIDE_DOWNLOAD_URL=https://github.com/Masterminds/glide/releases/download/$GLIDE_VERSION/glide-$GLIDE_VERSION-linux-amd64.tar.gz
chroot $TARGET_ROOTFS /bin/bash -e <<EOF
#Качаем Glide (распаковываем в /usr/local/bin, уже в PATH)
curl -fsSL "\$GLIDE_DOWNLOAD_URL" -o glide.tar.gz
tar -C /usr/local/bin --strip-components=1 -xzf glide.tar.gz linux-amd64/glide
rm glide.tar.gz
EOF
#cat $TARGET_ROOTFS/root/log.txt
#rm $TARGET_ROOTFS/root/log.txt

chroot $TARGET_ROOTFS /bin/bash -e <<EOF
#FixMe! Найти, почему PATH НЕ полон Или изначально или где-то портится.
PATH=/usr/local/sbin:/usr/sbin:\$PATH
cd /tmp
mkdir wb_build_tmp
cd wb_build_tmp
git clone https://github.com/contactless/libwbmqtt.git
cd libwbmqtt && dpkg-buildpackage -us -uc
cd ..
dpkg -i libwbmqtt*.deb
rm -rf /tmp/wb_build_tmp
# build and install google test
#Успешность - можно проверить 
#ls /usr/lib/libg* /wc -l
#Должно возвращать 2
cd /usr/src/gtest && cmake . && make && mv libg* /usr/lib/
ln -s /usr/src/gtest /usr/src/gmock/gtest
EOF




do_build() {
	export RELEASE=$1 ARCH=$2 BOARD=$3
#	export ROOTFS="/rootfs/$RELEASE-$ARCH"
#	time /root/rootfs/create_rootfs.sh $BOARD
#	rm -f /root/output/rootfs_base_${ARCH}.tar.gz
#	/root/prep.sh
}

do_build stretch armhf 6x

