#!/bin/bash

set -e

read -s -p "Enter Admin Password: " ADMIN_PASSWORD
echo ""

PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
RED='\033[0;31m'
NC='\033[0m'

PASSWORD_SECRET=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 96)
ROOT_PASSWORD_SHA2=$(echo -n "$ADMIN_PASSWORD" | sha256sum | cut -d" " -f1)
OPENSEARCH_ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c 16)
HEADLESS_INSTALL="false"

TOTAL_MEM=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
HEAP_SIZE=$((TOTAL_MEM / 2 / 1024 / 1024))
HEAP_SIZE="${HEAP_SIZE}G"


check() {
  OUT=$?
  if [ $OUT -ne 0 ]; then
    #sudo journalctl -xe
    echo "There is a problem in installing the monitoring tools. Please take a look at the logs above to understand the problem. If you need help, please send the log of this console to support@antmedia.io"
    exit $OUT
  fi
}

distro () {
  os_release="/etc/os-release"
  if [ -f "$os_release" ]; then
    . $os_release
    msg="We are supporting Ubuntu 20.04, Ubuntu 22.04, Ubuntu 24.04"

  elif [ "$ID" == "ubuntu" ] || [ "$ID" == "centos" ]; then
      if [ "$VERSION_ID" != "20.04" ] && [ "$VERSION_ID" != "22.04" ] && [ "$VERSION_ID" != "24.04" ]; then
         echo $msg
         exit 1
      fi
  else
      echo $msg
      exit 1
  fi
}

check_network () {

  if [ "$HEADLESS_INSTALL" == "false" ]; then
      echo -e "Are you using the monitoring tool behind the NAT network? [Y/n]"
      read nat
      nat=${nat^}
      if [ "$nat" == "Y" ]; then
         read -p "Please enter your private IP: " private_ip
         PRIVATE_IP=$private_ip
         if [ -z $PRIVATE_IP ]; then
            echo "Private IP cannot be empty."
            exit 1
         fi
      else
         PRIVATE_IP="127.0.0.1"
      fi
  else
    #default value is not installing behind NAT
    PRIVATE_IP="127.0.0.1"
  fi
  if [ "$nat" == "Y" ]; then
      LOGIN_IP=$PRIVATE_IP
  else
      LOGIN_IP=$PUBLIC_IP
  fi
}

check_ip() {
  if [[ $PRIVATE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
     echo ""
  else
     echo -e "\e[41mPlease enter valid IP address.${NC}"
     check_network
  fi
}

distro
check_network
check_ip

# MongoDB 
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod
check

# OpenSearch 
sudo apt-get update && sudo apt-get -y install lsb-release ca-certificates curl gnupg2
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-2.x.list
sudo apt-get update
sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD="$OPENSEARCH_ADMIN_PASSWORD" apt-get install opensearch -y
check

# OpenSearch 
cat <<EOF | sudo tee /etc/opensearch/opensearch.yml
cluster.name: graylog
discovery.type: single-node
network.host: 0.0.0.0
action.auto_create_index: false
plugins.security.disabled: true
EOF

sudo systemctl enable graylog-datanode.service
sudo systemctl start graylog-datanode.service

# Graylog 
wget https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.deb
sudo dpkg -i graylog-6.1-repository_latest.deb
sudo apt-get update
sudo apt-get install -y graylog-datanode graylog-server
check

# Graylog Configuration
sudo sed -i "s/^password_secret =.*$/password_secret = $PASSWORD_SECRET/" /etc/graylog/server/server.conf
sudo sed -i "s/^root_password_sha2 =.*$/root_password_sha2 = $ROOT_PASSWORD_SHA2/" /etc/graylog/server/server.conf

echo "opensearch_heap = $HEAP_SIZE" | sudo tee -a /etc/graylog/datanode/datanode.conf
sudo sed -i "s/^password_secret =.*$/password_secret = $PASSWORD_SECRET/" /etc/graylog/datanode/datanode.conf

cat <<EOF | sudo tee -a /etc/graylog/server/server.conf
message_journal_max_age = 24h
message_journal_max_size = 5gb
http_bind_address = 0.0.0.0:9000
EOF

sudo systemctl daemon-reload
sudo systemctl enable graylog-server.service
sudo systemctl start graylog-server.service
check

echo ""
echo "==========================================="
echo " INSTALLATION COMPLETE - FOLLOW THESE STEPS"
echo "==========================================="
echo ""
echo "1. Complete the Preflight Login process by following these steps:"
echo "   - Check the /var/log/graylog-server/server.log file."
echo "   - Use the credentials found in the log file to complete the preflight setup."
echo ""
echo "2. After logging into Graylog, run the following REST API call to create the input:"
echo ""
echo "   curl -X POST \"http://127.0.0.1:9000/api/system/inputs\" \\"
echo "       -u \"admin:$ADMIN_PASSWORD\" \\"
echo "       -H \"Content-Type: application/json\" \\"
echo "       -H \"X-Requested-By: CLI\" \\"
echo "       -d '{"
echo "           \"title\": \"GELF UDP Input\","
echo "           \"global\": true,"
echo "           \"type\": \"org.graylog2.inputs.gelf.udp.GELFUDPInput\","
echo "           \"configuration\": {"
echo "               \"bind_address\": \"0.0.0.0\","
echo "               \"port\": 12201,"
echo "               \"recv_buffer_size\": 262144,"
echo "               \"number_worker_threads\": 2,"
echo "               \"override_source\": null"
echo "           },"
echo "           \"node\": null"
echo "       }'"
echo ""
echo "==========================================="
echo -e " Graylog Dashboard Username: ${RED}admin${NC}"
echo -e " Graylog Dashboard Password: ${RED}$ADMIN_PASSWORD${NC}"
echo -e " Login URL: ${RED}http://$LOGIN_IP:9000${NC}"
echo "==========================================="
