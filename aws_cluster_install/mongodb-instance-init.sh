#!/bin/bash
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list
apt-get update
#install mongodb
apt-get install -y mongodb-org

#change the bind ip value 
sed -i "s/bindIp:.*127.0.0.1/bindIp: 0.0.0.0/"  /etc/mongod.conf 

#restart the service
service mongod restart
#enable the service
systemctl enable mongod.service
