#!/bin/bash

schroot -c bullseye-amd64-sbuild --directory=/ -- bash -c 'echo "deb http://deb.wirenboard.com/wb7/bullseye unstable main" > /etc/apt/sources.list.d/wirenboard-unstable.list'
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get update 
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get -y install libwbmqtt1-4:armhf libwbmqtt1-4-dev:armhf libwbmqtt1-4-test-utils:armhf j2cli:all gdbserver:armhf lcov libdb5.3++-dev:armhf libsqlite3-dev:armhf libsqlite3-0:armhf

dir=$(pwd)
schroot -c bullseye-amd64-sbuild --directory=/ -- mkdir -p $dir
echo "$dir  $dir   none    rw,bind         0       0" >> /etc/schroot/sbuild/fstab

apt update
apt install gdb-multiarch
