#!/bin/bash

dir=$(pwd)
schroot -c bullseye-amd64-sbuild --directory=/ -- mkdir -p $dir
echo "$dir  $dir   none    rw,bind         0       0" >> /etc/schroot/sbuild/fstab

apt update

schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get update
schroot -c bullseye-amd64-sbuild --directory=/ -- apt-get -y install golang-1.21-go:native
