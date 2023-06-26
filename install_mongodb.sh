#!/bin/bash
#
# MongoDB Installation Script
#
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y curl gnupg2
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/mongodb-server-6.0.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org

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
