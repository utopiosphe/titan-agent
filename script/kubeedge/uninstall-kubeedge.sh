#!/bin/bash

### remove containerd
uninstall_containerd() {
    systemctl stop containerd
    systemctl disable containerd
    apt remove --purge containerd -y
    apt autoremove --purge -y

    rm -rf /etc/containerd/
    rm -rf /usr/local/etc/containerd/
    rm -rf /var/lib/containerd/
}

### remove cni
uninstall_cni() {
    rm -rf /opt/cni
}

### remove uuid
uninstall_uuid() {
     apt remove uuid
}

uninstall_yq() {
    rm /usr/local/bin/yq 
}

uninstall_kubeedge() {
    rm /usr/local/bin/keadm
    rm /usr/local/bin/edgecore
}


{
    uninstall_containerd
    uninstall_cni
    uninstall_uuid
    uninstall_yq
    uninstall_kubeedge
}