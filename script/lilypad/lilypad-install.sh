### install docker
if command -v docker > /dev/null 2>&1; then
    echo "Docker is installed. Version information is as follows:"
    docker version
else
    echo "Docker is not installed. Now starting installation..."
    
    apt install -y apt-transport-https ca-certificates curl software-properties-common

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce
    systemctl enable docker
    systemctl start docker
fi

if command -v docker > /dev/null 2>&1; then
    docker pull ghcr.io/lilypad-tech/resource-provider:latest
    docker run -d --name lilypad-resource-provider --gpus all -e WEB3_PRIVATE_KEY=<private key> --restart always ghcr.io/lilypad-tech/resource-provider:latest
    docker run -d --name lilypad-watchtower --restart always -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower lilypad-resource-provider --interval 300
fi
