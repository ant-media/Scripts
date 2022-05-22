#!/bin/bash
#
# Turn Server Installation Script
# 

IP=`curl http://checkip.amazonaws.com`
USERNAME=$(openssl rand -hex 6)
PASSWORD=$(openssl rand -hex 12)


sudo apt-get update && apt-get install coturn -y
echo "TURNSERVER_ENABLED=1" > /etc/default/coturn
echo "realm=$IP" >> /etc/turnserver.conf
echo "user=$USERNAME:$PASSWORD" >> /etc/turnserver.conf
sudo systemctl enable coturn && sudo systemctl restart coturn

echo "Turn Server Address: $IP"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"



