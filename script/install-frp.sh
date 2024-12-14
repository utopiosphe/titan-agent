#!/bin/bash

rm frp.tar.gz
wget https://agent.titannet.io/frp/frp.tar.gz
tar -xvf frp.tar.gz -C /usr/local
rm frp.tar.gz

UUID=$(cat /etc/machine-id)
sed -i "s/name = \"ssh2\"/name = \"$UUID\"/g" /usr/local/frp/frpc.toml
sed -i "s/customDomains = \[\"machine-a.example.com\"\]/customDomains = \[\"$UUID\"\]/g" /usr/local/frp/frpc.toml

systemctl enable /usr/local/frp/frpc.service
systemctl start frpc