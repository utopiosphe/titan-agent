#!/bin/bash

# Check if QEMU is installed
if command -v qemu-system-x86_64 > /dev/null 2>&1; then
    echo "QEMU is installed. Version information is as follows:"
    qemu-system-x86_64 --version
else
    echo "QEMU is not installed. Now starting installation..."
    apt update
    apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
    echo "QEMU installation completed."
fi


## modify /etc/libvirt/qemu.conf, set user=root
CONFIG_FILE="/etc/libvirt/qemu.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not exist."
    exit 1
fi

if grep -q "^user[[:space:]]*=[[:space:]]*\"root\"" "$CONFIG_FILE"; then
    echo "Already set /etc/libvirt/qemu.conf user=root."
else
    echo "to be change /etc/libvirt/qemu.conf, and set user=root"

    if grep -q "^#user[[:space:]]*=" "$CONFIG_FILE"; then
        sed -i 's/^#user[[:space:]]*=[[:space:]]*".*"/user = "root"/' "$CONFIG_FILE"
    else
        echo "user=root" >> "$CONFIG_FILE"
    fi

    echo "update /etc/libvirt/qemu.conf, set user=root."

    systemctl restart libvirtd

    sleep 1
    if ! systemctl is-active --quiet libvirtd; then 
        echo "libvirtd restart failed"
        exit1
    fi

    echo "libvirtd restart success."
fi