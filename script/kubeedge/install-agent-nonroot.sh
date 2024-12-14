#!/bin/bash
### titan-agent workspace
### this is config in titan-agent.service
mkdir /opt/titan
chmod 777 /opt/titan
## 下载titan-agent
wget https://github.com/zscboy/titan-agent/releases/download/0.1.1/titan-agent-0.1.1.zip

## 解压文件到安装目录/usr/local,目前必须是这个目录，否则service跑不起来
unzip titan-agent-0.1.1.zip -d /usr/local/

## 修改权限
chmod +x /usr/local/titan-agent/titan-agent

## 复制service到system目录下
cp /usr/local/titan-agent/titan-agent.service /etc/systemd/system/

### 启动
systemctl enable titan-agent
systemctl start titan-agent

USER="titan"
useradd $USER

SERVICE_FILE="/etc/systemd/system/titan-agent.service"

if [[ ! -f $SERVICE_FILE ]]; then
    echo "服务文件不存在"
    exit 1
fi

cp "$SERVICE_FILE" "$SERVICE_FILE.bak"

sed -i "/^\[Service\]/a User=$USER\nGroup=$USER" "$SERVICE_FILE"

echo "User 和 Group 已插入 $SERVICE_FILE"


SUDOERS_LINE="$USER ALL=(ALL) NOPASSWD: /usr/local/bin/keadm"

# 检查是否已经存在
if grep -q "^$SUDOERS_LINE" /etc/sudoers; then
    echo "该行已存在于 sudoers 文件中"
else
    # 使用 tee 以 root 权限插入行
    echo "$SUDOERS_LINE" | sudo tee -a /etc/sudoers > /dev/null
    echo "已插入 $SUDOERS_LINE 到 sudoers 文件中"
fi

systemctl daemon-reload
systemctl restart titan-agent