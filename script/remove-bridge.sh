#!/bin/bash

ip link del br0

systemctl stop dnsmasq
systemctl disable dnsmasq

apt-get remove -y --purge dnsmasq dnsmasq-base
apt-get remove -y --purge dnsmasq-utils


systemctl stop einat
systemctl disable einat
rm /usr/local/bin/einat
rm /etc/systemd/system/einat.service
