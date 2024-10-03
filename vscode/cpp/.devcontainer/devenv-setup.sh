#!/bin/bash

schroot -c bullseye-amd64-sbuild --directory=/ -- bash -c 'echo "deb http://deb.wirenboard.com/wb7/bullseye unstable main" > /etc/apt/sources.list.d/wirenboard-unstable.list'
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get update
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get -y install gdbserver:armhf gcovr:all j2cli:all
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get -y install libwbmqtt1-5-test-utils:armhf libdb5.3++-dev:armhf libsqlite3-dev:armhf

dir=$(pwd)
schroot -c bullseye-amd64-sbuild --directory=/ -- mkdir -p $dir
echo "$dir  $dir   none    rw,bind         0       0" >> /etc/schroot/sbuild/fstab

apt update
apt install gdb-multiarch
