#!/bin/bash

# setup timezone
echo "[TASK 0] Set timezone"
timedatectl set-timezone Asia/Shanghai
apt-get install -y ntpdate >/dev/null 2>&1
ntpdate ntp.aliyun.com

echo "[TASK 1] install some tools"
apt install -qq -y vim jq iputils-ping net-tools >/dev/null 2>&1

echo "[TASK 2] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 3] Stop and Disable firewall"
systemctl disable --now ufw >/dev/null 2>&1

echo "[TASK 4] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 5] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 6] Install kata and containerd runtime"

#bash -c "$(curl -fsSL https://raw.githubusercontent.com/kata-containers/kata-containers/main/utils/kata-manager.sh)"

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt -qq update >/dev/null 2>&1
apt install -qq -y containerd.io >/dev/null 2>&1
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i 's/registry.k8s.io\/pause:3.6/registry.aliyuncs.com\/google_containers\/pause:3.9/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1


echo "[TASK 7] Add apt repo for kubernetes"
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update >/dev/null 2>&1
sudo apt-get install -y kubelet kubeadm kubectl

