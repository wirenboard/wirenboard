#!/bin/bash

case $1 in
up)
    touch /var/leases
    modprobe g_ether
    ifconfig usb0 192.168.41.1 netmask 255.255.255.0 up
    udhcpd
    while ! ping -c 1 192.168.41.2; do true; done; echo 'Host is online'
;;
down)
    killall udhcpd
    ifconfig usb0 down
    modprobe -r g_ether
;;
esac
