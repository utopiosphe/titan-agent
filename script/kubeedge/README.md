1. titan-candidate怎么自动获取code
2. titan-candidate怎么绑定到自己的帐号

wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq &&\
    chmod +x /usr/local/bin/yq
yq eval '.modules.edged.tailoredKubeletConfig.clusterDNS = ["223.5.5.5"]' -i /etc/kubeedge/config/edgecore.yaml