#!/bin/bash

### Install containerd #################
install_containerd() {
    if command -v containerd > /dev/null 2>&1; then
        echo "Containerd is installed. Version information is as follows:"
        containerd -v
    else
        apt update
        apt install -y apt-transport-https ca-certificates curl uuid

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

        apt update
        DEBIAN_FRONTEND=noninteractive apt install -y containerd.io

        systemctl restart containerd
        systemctl enable containerd
    fi
}

##################################################################
### Install cni ################
install_cni() {
    cnidir="/opt/cni"
    if [ -d "$cnidir" ]; then
        rm -rf "$cnidir"
        echo "remove $cnidir"
    fi

    # arch=$(uname -m); 
    # if [[ $arch != x86_64 ]]; then 
    #     arch='arm64'; 
    # else 
    #     arch='amd64'; 
    # fi;  
    
    # curl -LO https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-$arch-v1.6.0.tgz  
    curl -LO https://agent.titannet.io/kubeedge/cni-plugins-linux-amd64-v1.6.0.tgz 
    mkdir -p $cnidir/bin
    tar xvf cni-plugins-linux-amd64-v1.6.0.tgz -C $cnidir/bin
    rm cni-plugins-linux-amd64-v1.6.0.tgz

cat >/etc/cni/net.d/10-containerd-net.conflist <<EOF
{
    "cniVersion": "1.0.0",
    "name": "containerd-net",
    "plugins": [
        {
        "type": "bridge",
        "bridge": "cni0",
        "isGateway": true,
        "ipMasq": true,
        "promiscMode": true,
        "ipam": {
            "type": "host-local",
            "ranges": [
            [{
                "subnet": "10.88.0.0/16"
            }],
            [{
                "subnet": "2001:db8:4860::/64"
            }]
            ],
            "routes": [
            { "dst": "0.0.0.0/0" },
            { "dst": "::/0" }
            ]
        }
        },
        {
        "type": "portmap",
        "capabilities": {"portMappings": true}
        }
    ]
}
EOF

}
##################################################################
### Install uuid ##############
install_uuid() {
    if command -v uuid > /dev/null 2>&1; then
        echo "uuid is installed."
    else
        apt install -y uuid
    fi
}

### Install yq ##############
install_yq() {
    if command -v yq > /dev/null 2>&1; then
        echo "yq is installed."
    else
        wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq
    fi
}


################################################################
### Install kubeedge ###############
install_kubeedge() {
    if command -v keadm > /dev/null 2>&1; then
        echo "keadm is installed. Version information is as follows:"
        keadm version
    else
        ### remove kubeedge old config
        rm -rf /etc/kubeedge/

        # arch=$(uname -m); 
        # if [[ $arch != x86_64 ]]; then 
        #     arch='arm64'; 
        # else 
        #     arch='amd64'; 
        # fi;  
        
        # curl -LO  https://github.com/kubeedge/kubeedge/releases/download/v1.19.0/keadm-v1.19.0-linux-$arch.tar.gz
        curl -LO https://agent.titannet.io/kubeedge/keadm-v1.19.0-linux-amd64.tar.gz

        tar xvf keadm-v1.19.0-linux-amd64.tar.gz
        mv keadm-v1.19.0-linux-amd64/keadm/keadm /usr/local/bin 
        chmod +x /usr/local/bin  
        rm keadm-v1.19.0-linux-amd64.tar.gz
        rm -rf keadm-v1.19.0-linux-amd64
    fi
}

join_cluster() {
     keadm join --kubeedge-version=1.19.0 --cloudcore-ipport=8.218.162.82:10000  --edgenode-name $(uuid) --token c7dfdc642e51dd377fb86f50ea138256ae232e2b3c2ccc07e90b1552a6b86946.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MzE5OTE1MjZ9.MQNjP66MxOeTNafYM1sN2UaKWqVrYGh_S1i9kqH7-4c
}

{
    install_containerd
    install_cni
    install_uuid
    install_kubeedge
}