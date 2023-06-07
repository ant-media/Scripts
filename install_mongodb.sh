#!/bin/bash
#
# MongoDB Installation Script
#

sudo apt-get update
sudo apt-get install -y curl gnupg2
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/mongodb-server-6.0.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
