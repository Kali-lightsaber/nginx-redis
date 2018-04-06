#!/usr/bin/env bash
set -e

# check conditions
if [ -z "$1" ]; then
	echo "First argument to this script must be the environment (staging/production)"
	exit 1
fi
if [ -z "$2" ]; then
	echo "Second argument to this script must be the url of the backend redis instance"
	exit 1
fi
if [ -z "$3" ]; then
	echo "Third argument to this script must be the ID of our AWS ECR"
	exit 1
fi
if (( $EUID != 0 )); then
    echo "Please run as root"
    exit 1
fi

# CONSTANTS
ENV_NAME="$1"
REDIS_HOST="$2"
AWS_ECS_ID="$3"

# updates
apt update && sudo apt upgrade -y

# install docker
apt install -y apt-transport-https ca-certificates curl software-properties-common python3-pip
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
apt update
apt install -y docker-ce
usermod -a -G docker ubuntu

# setup AWS CLI and log into the private docker repository
pip3 install --upgrade pip
pip3 install awscli
$(aws ecr get-login --no-include-email --region us-east-1)

# generate certs
docker volume create ca
docker run -v ca:/root/ca:rw --name redis-ca -d ${AWS_ECS_ID}/redis-ca:${ENV_NAME}

# run nginx
docker run -v ca:/root/ca:ro --name nginx --restart always -d -e "REDIS_HOST=${REDIS_HOST}" -p "6379:6379" ${AWS_ECS_ID}/nginx-streaming:1.12.2

# copy client cert materials locally
cp /var/lib/docker/volumes/ca/_data/certs/client.pem .
cp /var/lib/docker/volumes/ca/_data/certs/ca.pem .
cp /var/lib/docker/volumes/ca/_data/private/client.key .
apt install -y zip
zip -r client-cert.zip client.pem ca.pem client.key

# done
echo "Complete - you can now exit from this instance and scp client-cert.zip to you"
