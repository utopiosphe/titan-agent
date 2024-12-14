#!/bin/bash
#set -e
#1. 在netplan配置网桥
#2. 配置iptable
#3. 安装dnsmasq
#4. 修改虚拟机的配置，重启虚拟机
if [ "$#" -eq 0 ]; then
    echo "Specify a path to store the image."
    exit 1
else
    echo "install ssd on: $@"
fi

apt install -y net-tools

#######################################################
########## create bridge br0 ###########################
if ip link show br0 > /dev/null 2>&1; then
  echo "bridge br0 already exist"
else
    ip link add name br0 type bridge
    ip addr add 192.168.100.1/24 brd + dev br0
    ip link set br0 up
fi


######## allow br0 forward
if ! iptables -S FORWARD | grep -q "FORWARD -i br0 -j ACCEPT"; then
    echo "iptables -t filter -A FORWARD -i br0 -j ACCEPT"
    iptables -t filter -A FORWARD -i br0 -j ACCEPT
else
    echo "iptable rule: 'iptables -t filter -A FORWARD -i br0 -j ACCEPT' alread exist"
fi

if ! iptables -S FORWARD | grep -q "FORWARD -o br0 -j ACCEPT"; then
    echo "iptables -t filter -A FORWARD -o br0 -j ACCEPT"
    iptables -t filter -A FORWARD -o br0 -j ACCEPT
else
    echo "iptable rule: 'iptables -t filter -A FORWARD -o br0 -j ACCEPT' alread exist"
fi

#######################################################
########## install dnsmasq ###########################

# 检查 dnsmasq 服务是否存在
if systemctl list-units --type=service --all | grep -q "dnsmasq.service"; then
    echo "dnsmasq service exists"
else
    echo "dnsmasq service does not exist, install..."

    virsh net-destroy default
    virsh net-autostart default --disable
    # systemctl stop systemd-resolved.service
    # systemctl disable systemd-resolved.service

    ## remove dnsmasq
    apt remove -y dnsmasq

    DEBIAN_FRONTEND=noninteractive apt install -y dnsmasq

    DNSMASQ_CONF="/etc/dnsmasq.conf"
    echo "interface=br0" >> "$DNSMASQ_CONF"
    echo "dhcp-range=192.168.100.2,192.168.100.254,255.255.255.0,12h" >> "$DNSMASQ_CONF"

    systemctl enable dnsmasq
    systemctl restart dnsmasq
fi


### 检查einet是否存在
if systemctl list-units --type=service --all | grep -q "einat.service"; then
    echo "einat service exists"
else
    echo "einat service does not exist, install..."

    sysctl -w net.ipv4.ip_forward=1

    wget https://agent.titannet.io/einat-static-x86_64-unknown-linux-musl
    mv einat-static-x86_64-unknown-linux-musl /usr/local/bin/einat
    chmod +x /usr/local/bin/einat

    interface=$(ip -o -4 addr show | grep -E "en|eth|bond" | grep -E '^[2-9]' | awk '{print $2}')
    ###　get network interface
    SERVICE_FILE="/etc/systemd/system/einat.service"
    cat >$SERVICE_FILE <<EOF
[Unit]
Description=Einat eBPF Service
Wants=network-online.target
After=network.target network-online.target

[Service]
Restart=always
ExecStart=/usr/local/bin/einat --ifname $interface

[Install]
WantedBy=multi-user.target
EOF


    systemctl enable einat
    systemctl start einat
fi



## modify /etc/libvirt/qemu.conf, set user=root
CONFIG_FILE="/etc/libvirt/qemu.conf"
if grep -q "security_default_confined = 0" "$CONFIG_FILE"; then
    echo "Already set security_default_confined = 0"
else
    sed -i "s/#security_default_confined = 1/security_default_confined = 0/g" $CONFIG_FILE
    echo "set security_default_confined = 0"

    systemctl restart libvirtd

    sleep 1
    if ! systemctl is-active --quiet libvirtd; then 
        echo "libvirtd restart failed"
        exit1
    fi

    echo "libvirtd restart success."
fi

######### Add ssd disk #############
VM_XML_FILE="/etc/libvirt/qemu/Painet.xml"
if grep -q "<qemu:commandline>" "$VM_XML_FILE"; then
    echo "NVME already exist"
else
    IMAGE_DIR=$1
    DISK_PATH="$IMAGE_DIR/Painet-2.qcow2"
    qemu-img create -f qcow2 $DISK_PATH 1024G
    modprobe nbd
    qemu-nbd --connect=/dev/nbd0 $DISK_PATH
    echo -e "n\np\n1\n\n\nw" | fdisk /dev/nbd0
    mkfs.xfs -f /dev/nbd0
    qemu-nbd --disconnect /dev/nbd0

    INSERT_POS=$(grep -n '</devices>' $VM_XML_FILE | cut -d: -f1)
    if [ -n "$INSERT_POS" ]; then
        sed -i "${INSERT_POS}a <commandline xmlns=\"http://libvirt.org/schemas/domain/qemu/1.0\">" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a <arg value='-device'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a       <arg value='nvme,id=nvme-0,serial=12340'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a       <arg value='-drive'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a       <arg value='format=qcow2,file=$DISK_PATH,if=none,id=nvme-0-driver0'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a       <arg value='-device'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a       <arg value='nvme-ns,drive=nvme-0-driver0,bus=nvme-0,nsid=1,zoned=false,logical_block_size=4096,physical_block_size=4096'/>" $VM_XML_FILE
        INSERT_POS=$((INSERT_POS + 1)) 
        sed -i "${INSERT_POS}a   </commandline>" $VM_XML_FILE

        echo "Added qemu:commandline to $VM_XML_FILE"
    else
        echo "Cannot find </devices> in $VM_XML_FILE"
    fi
fi


########## change network to br0 ################
sed -i "s/<interface type='network'>/<interface type='bridge'>/g" $VM_XML_FILE
sed -i "s/<source network='default'\/>/<source bridge='br0'\/>/g" $VM_XML_FILE
sed -i "s/<model type='virtio'\/>/<model type='virtio-net-pci'\/>/g" $VM_XML_FILE
echo "Replace network config"


#### restart Painet
virsh define $VM_XML_FILE
virsh destroy Painet
sleep 3
virsh start Painet

echo "Restart vm Painet"