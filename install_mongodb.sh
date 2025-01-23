#!/bin/bash
#
# MongoDB Installation Script
#

help() {
  echo "Usage: $0"
  echo ""
  echo "Options:"
  echo "  --auto-create  Automatically create a MongoDB user with a random username and password"
  echo "  --help         Show this help menu"
}

if [ "$1" == "--help" ]; then
  help
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y curl gnupg2

ubuntu_version=$(lsb_release -rs)

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor


if [[ "$ubuntu_version" == "24.04" ]]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
elif [[ "$ubuntu_version" == "22.04" ]]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
elif [[ "$ubuntu_version" == "20.04" ]]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
else
  echo "Unsupported Ubuntu version: $ubuntu_version"
  exit 1
fi

sudo apt-get update
sudo apt-get install -y mongodb-org

if [[ $1 == "--auto-create" ]]; then
  # Generate a random username and password
  username=$(openssl rand -hex 6)
  password=$(openssl rand -hex 12)

  # Start MongoDB and configure authentication
  sudo systemctl restart mongod
  sudo systemctl enable mongod

  sleep 10

  echo "use admin;
  db.createUser({ user: '$username', pwd: '$password', roles: ['root'], mechanisms: ['SCRAM-SHA-1'] });" | mongosh

  sudo sed -i 's/#security:/security:\n  authorization: "enabled"/g' /etc/mongod.conf
  sudo sed -i 's/bindIp:.*/bindIp: 0.0.0.0/g' /etc/mongod.conf
  sudo systemctl restart mongod

  echo "MongoDB username: $username"
  echo "MongoDB password: $password"
else
  # Start MongoDB without authentication
  sudo sed -i 's/bindIp:.*/bindIp: 0.0.0.0/g' /etc/mongod.conf
  sudo systemctl restart mongod
  sudo systemctl enable mongod

  echo "MongoDB installed without username and password"
fi
