#!/bin/bash

case $1 in
up)
    touch /var/leases

    # Set explicit MAC addresses in order to have a consistent interface name.
    # Without explicit addresses g_ether generates random ones.
    modprobe g_ether dev_addr=12:34:56:78:9a:bc host_addr=12:34:56:78:9a:bd

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
