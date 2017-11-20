#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "first argument to this script must be the url of the backend redis instance"
    exit 1
fi

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip docker-ce

pip3 install --upgrade pip
pip3 install awscli --upgrade --user 

sudo usermod -a -G docker ubuntu
$(aws ecr get-login --no-include-email --region us-east-1)

sudo docker volume create ca
sudo docker run -v ca:/root/ca:rw --name redis-ca -d 366985115424.dkr.ecr.us-east-1.amazonaws.com/redis-ca:latest
sudo docker run -v ca:/root/ca:ro --name nginx -d -e "REDIS_HOST=$1" -p "6379:6379" 366985115424.dkr.ecr.us-east-1.amazonaws.com/nginx-streaming:1.12.2