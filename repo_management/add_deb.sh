#!/bin/sh
for var in "$@"; do
    aptly repo add wirenboard-release $var
done
