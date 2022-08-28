#!/bin/bash

PUBLIC_IP="$(curl -s http://checkip.amazonaws.com)"

sudo apt-get update
sudo apt-get install apt-transport-https openjdk-11-jre openjdk-11-jre-headless uuid-runtime pwgen gnupg -y

wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu `lsb_release -cs`/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update && sudo apt-get install -y mongodb-org -y
sudo systemctl restart mongod

wget -O - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt-get update && sudo apt-get install elasticsearch-oss -y

sudo tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOT
cluster.name: graylog
action.auto_create_index: false
EOT

sudo systemctl enable elasticsearch.service
sudo systemctl restart elasticsearch.service

wget https://packages.graylog2.org/repo/packages/graylog-4.3-repository_latest.deb
sudo dpkg -i graylog-4.3-repository_latest.deb
sudo apt-get update && sudo apt-get install graylog-server -y

sed -i -e 's/password_secret =.*/password_secret = '$(pwgen -s 96 1)'/' /etc/graylog/server/server.conf
sed -i -e 's/root_password_sha2 =.*/root_password_sha2 = '$(echo -n graylog_password | shasum -a 256 | awk '{print $1}')'/' /etc/graylog/server/server.conf
sed -i -e 's/#http_bind_address = 127.*/http_bind_address = '$PUBLIC_IP':9000/' /etc/graylog/server/server.conf

sudo systemctl enable graylog-server.service
sudo systemctl restart graylog-server.service
sleep 10

curl -u admin:graylog_password -H 'Content-Type: application/json' -X POST http://$PUBLIC_IP:9000/api/system/inputs -d '{
    "title": "Ant Media Server",
    "type": "org.graylog2.inputs.syslog.udp.SyslogUDPInput",
    "global": true,
    "configuration":   {
          "number_worker_threads": 2,
          "bind_address": "0.0.0.0",
          "port": 5144,
          "override_source": null,
          "recv_buffer_size": 262144,
          "store_full_message": true
        },
    "node": null
  }' -H 'X-Requested-By: cli'