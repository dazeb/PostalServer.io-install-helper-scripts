#!/bin/bash

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]
 then echo "Please run as root"
 exit
fi

# Update packages
apt update && apt upgrade -y

# Install necessary system utilities
apt install -y git curl jq

# Clone the Postal installation helper repository
git clone https://postalserver.io/start/install /opt/postal/install
ln -s /opt/postal/install/bin/postal /usr/bin/postal

# Install Docker
echo -e "\n\nInstalling Docker..."
sh <(curl -sSL https://get.docker.com)
if [ $? -eq 0 ]; then
    echo -e "\033[0;32mDocker installation succeeded.\033[0m"
else
    echo -e "\033[0;31mDocker installation failed.\033[0m"
    exit 1
fi

# Install Docker Compose
echo -e "\n\nInstalling Docker Compose..."
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
docker compose version
if [ $? -eq 0 ]; then
    echo -e "\033[0;32mDocker Compose installation succeeded.\033[0m"
else
    echo -e "\033[0;31mDocker Compose installation failed.\033[0m"
    exit 1
fi

# Run MariaDB in a container
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=postal \
   mariadb

# Run RabbitMQ in a container
docker run -d \
   --name postal-rabbitmq \
   -p 127.0.0.1:5672:5672 \
   --restart always \
   -e RABBITMQ_DEFAULT_USER=postal \
   -e RABBITMQ_DEFAULT_PASS=postal \
   -e RABBITMQ_DEFAULT_VHOST=postal \
   rabbitmq:3.8

echo "DONE"

# Ask user if they want to install Portainer
echo -n "Do you want to install Portainer? (yes/no): "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Install Portainer

echo -e "\n\nInstalling Portainer..."
docker volume create portainer_data
docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
if [ $? -eq 0 ]; then
    echo -e "\033[0;32mPortainer installation succeeded.\033[0m"
else
    echo -e "\033[0;31mPortainer installation failed.\033[0m"
    exit 1
fi


else
    echo "Portainer installation skipped. The rest of the install was successful."
    exit 0
fi
