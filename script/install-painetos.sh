#!/bin/bash

# Define the URL of the ISO file and the local path
ISO_URL="https://oss.painet.work/infra-devops-prod-1312767721/pai-iso/pai-network/PaiNetwork-1.1.7-compat-100g.iso"
ISO_PATH="/var/lib/libvirt/images/PaiNetwork-1.1.7-compat-100g.iso"

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

# Check if Expect is installed
if command -v expect > /dev/null 2>&1; then
    echo "Expect is already installed."
else
    echo "Expect is not installed, proceeding with installation..."
    apt install -y expect

    echo "Expect installation complete."
fi

# Check if the virtual machine Painet exists
if virsh list --all | grep -q "Painet"; then
    echo "Painet already exists."
else
    echo "Virtual machine 'Painet' does not exist. Now starting installation..."

    # Download the ISO file (if not downloaded)
    if [ ! -f "$ISO_PATH" ]; then
        echo "ISO file not found. Downloading..."
        sudo mkdir -p /var/lib/libvirt/images
        sudo wget -O "$ISO_PATH" "$ISO_URL"
        echo "ISO file download completed."
    else
        echo "ISO file already exists."
    fi

    # Start installing the virtual machine
    virt-install \
        --virt-type kvm \
        --name=Painet \
        --os-variant=centos7.0 \
        --vcpus=4 \
        --memory=4096 \
        --disk path=/var/lib/libvirt/images/Painet.qcow2,size=200 \
        --graphics none \
        --noautoconsole \
        --location "$ISO_PATH" \
        --extra-args='console=tty0 console=ttyS0,115200n8 serial inst.stage2=hd:LABEL=PaiNetwork-1.1.7 ks=file:/ks_bios.ks quiet'
    echo "Virtual machine 'Painet' installation completed."
fi
