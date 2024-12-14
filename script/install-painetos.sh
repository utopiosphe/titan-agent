#!/bin/bash

# Define the URL of the ISO file and the local path
ISO_URL="https://oss.painet.work/infra-devops-prod-1312767721/pai-iso/pai-network/PaiNetwork-1.1.7-compat-100g.iso"
ISO_PATH="/var/lib/libvirt/images/PaiNetwork-1.1.7-compat-100g.iso"

if [ "$#" -eq 0 ]; then
    echo "Specify a path to store the image."
    exit 1
else
    echo "install painet on: $@"
fi

INSTALL_IMAGE_PATH=$1


#######################################################
########## create bridge br0 ###########################
if ip link show br0 > /dev/null 2>&1; then
  echo "bridge br0 already exist"
else
    ip link add name br0 type bridge
    ip addr add 192.168.100.1/24 brd + dev br0
    ip link set br0 up
fi


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

    cpu_cores=$(nproc)
    cpu_cores=$((cpu_cores - 2))

    if [ "$cpu_cores" -le 0 ]; then
        cpu_cores=$(nproc)
    fi


    total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    memory_mb=$(bc <<< "scale=0; $total_memory_kb / 1024")

    if (( $(echo "$memory_mb > 2048" | bc -l) )); then
        memory_mb=$(bc <<< "$memory_mb - 2048")
    fi

    echo "alocate memory $memory_mb"
    # Start installing the virtual machine
    virt-install \
        --virt-type kvm \
        --name=Painet \
        --os-variant=centos7.0 \
        --vcpus=$cpu_cores \
        --memory=$memory_mb \
        --disk path=$INSTALL_IMAGE_PATH,size=200 \
        --graphics none \
        --noautoconsole \
        --location "$ISO_PATH" \
        --network bridge=br0,model=virtio-net-pci \
        --extra-args='console=tty0 console=ttyS0,115200n8 serial inst.stage2=hd:LABEL=PaiNetwork-1.1.7 ks=file:/ks_bios.ks quiet'
    echo "Virtual machine 'Painet' installation completed."
fi
